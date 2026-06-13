# Supabase 接入指南 — 为个人博客添加点赞 & 评论

## 一、Supabase 是什么？

一句话：**免费的云端数据库 + 用户认证**。你不需要自己搭服务器，只需在前端 HTML 里引入一个 JS 库，就能读写数据库、做登录。

对个人博客来说，用它解决：
- 访客对随笔点赞（一人一票，去重）
- 访客对随笔评论（所有人可见）
- 只有你能编辑/删除随笔

---

## 二、注册 & 创建项目（5 分钟）

### 2.1 注册

1. 打开 https://supabase.com
2. 点右上角 **Sign in** → 用 GitHub 登录（推荐）

### 2.2 创建项目

1. 登录后点 **New project**
2. 填写：
   - **Name**：`zao-blog`（随意）
   - **Database Password**：生成一个强密码，**记下来**
   - **Region**：选 `Northeast Asia (Tokyo)`，国内访问最快
3. 点 **Create new project**，等待 1-2 分钟初始化

### 2.3 获取 API 密钥

1. 进入项目后，左侧菜单 → **Settings** → **API**
2. 你会看到两个关键值：
   - **Project URL**：类似 `https://xxxxx.supabase.co`
   - **anon public key**：很长一串，以 `eyJ` 开头
3. **把这两个值记下来**，后面要放进代码里

---

## 三、创建数据库表（5 分钟）

左侧菜单 → **SQL Editor** → **New query**，粘贴以下 SQL，点 **Run**：

```sql
-- 1. 评论表
CREATE TABLE comments (
  id        BIGSERIAL PRIMARY KEY,
  note_id   TEXT NOT NULL,              -- 关联到哪条随笔（用时间戳做 ID）
  content   TEXT NOT NULL,              -- 评论内容
  author    TEXT DEFAULT '匿名',         -- 评论者昵称
  created_at TIMESTAMPTZ DEFAULT now()
);

-- 2. 点赞表（一人一票）
CREATE TABLE likes (
  id        BIGSERIAL PRIMARY KEY,
  note_id   TEXT NOT NULL,
  user_id   TEXT NOT NULL,              -- 浏览器指纹 / 匿名 ID
  created_at TIMESTAMPTZ DEFAULT now(),
  UNIQUE(note_id, user_id)             -- 同一个人对同一条只能点一次
);

-- 3. 开启实时订阅（评论实时显示）
ALTER PUBLICATION supabase_realtime ADD TABLE comments;

-- 4. 索引加速查询
CREATE INDEX idx_comments_note ON comments(note_id);
CREATE INDEX idx_likes_note ON likes(note_id);
```

---

## 四、接入前端代码

### 4.1 引入 Supabase SDK

在 `index.html` 的 `<head>` 里加入：

```html
<script src="https://cdn.jsdelivr.net/npm/@supabase/supabase-js@2"></script>
```

### 4.2 初始化客户端

在 `<script>` 最前面，替换成你自己的 URL 和 key：

```js
const SUPABASE_URL = 'https://你的项目ID.supabase.co';
const SUPABASE_KEY = '你的 anon key';
const sb = supabase.createClient(SUPABASE_URL, SUPABASE_KEY);
```

### 4.3 生成访客 ID

每个访客需要一个唯一 ID 来做点赞去重（不需要登录）：

```js
function getVisitorId() {
  let id = localStorage.getItem('visitor_id');
  if (!id) {
    id = 'visitor_' + Date.now() + '_' + Math.random().toString(36).slice(2, 9);
    localStorage.setItem('visitor_id', id);
  }
  return id;
}
```

### 4.4 评论功能

```js
// 加载某条随笔的评论
async function loadComments(noteId) {
  const { data } = await sb
    .from('comments')
    .select('*')
    .eq('note_id', noteId)
    .order('created_at', { ascending: true });
  return data;
}

// 发布评论
async function postComment(noteId, content, author) {
  await sb.from('comments').insert({
    note_id: noteId,
    content: content,
    author: author || '匿名'
  });
}

// 删除评论（只允许站长）
async function deleteComment(commentId) {
  await sb.from('comments').delete().eq('id', commentId);
}
```

### 4.5 点赞功能

```js
// 获取某条随笔的点赞数
async function getLikeCount(noteId) {
  const { count } = await sb
    .from('likes')
    .select('*', { count: 'exact', head: true })
    .eq('note_id', noteId);
  return count;
}

// 检查当前访客是否已点赞
async function hasLiked(noteId, visitorId) {
  const { data } = await sb
    .from('likes')
    .select('*')
    .eq('note_id', noteId)
    .eq('user_id', visitorId)
    .maybeSingle();
  return !!data;
}

// 点赞 / 取消点赞
async function toggleLike(noteId, visitorId) {
  const liked = await hasLiked(noteId, visitorId);
  if (liked) {
    await sb.from('likes').delete().eq('note_id', noteId).eq('user_id', visitorId);
  } else {
    await sb.from('likes').insert({ note_id: noteId, user_id: visitorId });
  }
}
```

### 4.6 实时评论（可选，高级功能）

```js
// 订阅评论变化，新评论实时出现
sb.channel('comments')
  .on('postgres_changes',
    { event: 'INSERT', schema: 'public', table: 'comments' },
    (payload) => {
      // 新评论到达，刷新当前页面的评论列表
      if (payload.new.note_id === currentNoteId) {
        appendComment(payload.new);
      }
    }
  )
  .subscribe();
```

---

## 五、权限规则（RLS）

Supabase 默认禁止公开读写，需要开启权限。SQL Editor 执行：

```sql
-- 允许任何人读取评论
CREATE POLICY "comments_read" ON comments FOR SELECT USING (true);

-- 允许任何人发布评论
CREATE POLICY "comments_insert" ON comments FOR INSERT WITH CHECK (true);

-- 允许任何人读取点赞数
CREATE POLICY "likes_read" ON likes FOR SELECT USING (true);

-- 允许任何人点赞/取消
CREATE POLICY "likes_insert" ON likes FOR INSERT WITH CHECK (true);
CREATE POLICY "likes_delete" ON likes FOR DELETE USING (true);
```

---

## 六、收费说明

| 等级 | 价格 | 适合 |
|:--|:--|:--|
| **Free** | 免费 | 个人博客完美够用：500MB 数据库，5 万月活用户 |
| Pro | $25/月 | 更高配额 |

**免费版对个人博客完全够用。** 500MB 能存几十万条评论。

---

## 七、安全提醒

1. **anon key 是公开的**，可以放在前端代码里，这是设计如此
2. 真正的安全靠 **RLS Policy** 控制谁能读写什么
3. 不要在前端代码里放 **service_role key**（那个是管理员密钥）

---

## 八、下一步

要我帮你在现有的 `index.html` 里加上完整的评论和点赞功能吗？我会：

1. 引入 Supabase SDK
2. 给随笔加上评论区和点赞按钮
3. 评论区支持"站长删除"（你以管理员身份登录时可见删除按钮）
4. 提供设置管理员密码的方案（简单的密码验证）
