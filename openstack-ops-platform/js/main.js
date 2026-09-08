// ===== 초기화: 모든 화면 스크립트가 로드된 뒤 실행 =====
updateClock();
setInterval(updateClock, 30000);
loadProviders();
loadMenuPreferences();
renderInspectionChecklist();
renderInspectionSelection();
const initialPage = pageRegistry[location.hash.slice(1)] ? location.hash.slice(1) : 'dashboard';
showPage(initialPage);
if (initialPage === 'history') loadWorkHistories();
if (initialPage === 'alerts') loadAlerts(); else loadAlertSummary();
if (initialPage === 'settings') loadInspectionSettings();
renderDashboard(null);
loadFleetOverview();
startFleetRefresh();
loadSession();
