/**
 * 早哦早餐铺
 */
(function () {
  'use strict';

  var toastTimer = null;

  function showToast(message, duration) {
    duration = duration || 2000;
    var toast = document.querySelector('.toast');
    if (!toast) {
      toast = document.createElement('div');
      toast.className = 'toast';
      document.body.appendChild(toast);
    }
    toast.textContent = message;
    toast.classList.add('show');
    clearTimeout(toastTimer);
    toastTimer = setTimeout(function () {
      toast.classList.remove('show');
    }, duration);
  }

  function init() {
    var emailEl = document.getElementById('email-bottom');
    if (!emailEl) return;

    var email = emailEl.textContent.replace(/^📬\s*/, '').trim();
    emailEl.addEventListener('click', function () {
      if (navigator.clipboard && navigator.clipboard.writeText) {
        navigator.clipboard.writeText(email).then(function () {
          showToast('✅ 邮箱已复制: ' + email);
        }).catch(function () {
          fallback(email);
        });
      } else {
        fallback(email);
      }
    });
  }

  function fallback(text) {
    var ta = document.createElement('textarea');
    ta.value = text;
    ta.style.position = 'fixed';
    ta.style.left = '-9999px';
    document.body.appendChild(ta);
    ta.focus();
    ta.select();
    try { document.execCommand('copy'); showToast('✅ 邮箱已复制: ' + text); }
    catch (e) { showToast('⚠️ 复制失败'); }
    document.body.removeChild(ta);
  }

  if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', init);
  } else {
    init();
  }
})();
