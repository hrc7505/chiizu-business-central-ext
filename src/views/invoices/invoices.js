/* (function () {
  // Only call OnJsReady once
  if (window._controlInitialized) return;
  window._controlInitialized = true;

  window.DisplayList = function (title, jsonData) {
    renderList(title, jsonData, (item) => {
      const li = document.createElement("li");
      li.textContent = `${item.No} - ${item.Amount}`;

      return li;
    })
  };

  // Notify AL that JS is ready only once
  if (window.Microsoft && Microsoft.Dynamics && Microsoft.Dynamics.NAV) {
    Microsoft.Dynamics.NAV.InvokeExtensibilityMethod("OnJsReady", []);
  }
})(); */
(function () {
  if (window._controlInitialized) return;
  window._controlInitialized = true;

  const listId = "chiizu-list";

  window.DisplayList = function (title, jsonData) {

    console.log(title, jsonData);
    
    renderList(title, jsonData, (item) => {
      const li = document.createElement("li");
      li.textContent = `${item.No} - ${item.Amount}`;
      return li;
    });

    // Setup scroll event (once)
    const root = document.getElementById("controlAddIn");
    if (!root._scrollListenerAttached) {
      root.addEventListener("scroll", () => {
        if (root.scrollTop + root.clientHeight >= root.scrollHeight - 50) {
          Microsoft.Dynamics.NAV.InvokeExtensibilityMethod("loadMore", []);
        }
      });
      root._scrollListenerAttached = true;
    }
  };

  // Append-only render support
  window.appendData = function (jsonData) {
    console.log("append",jsonData);
    
    const list = JSON.parse(jsonData);
    const ul = document.getElementById(listId);
    if (!ul) return;

    list.forEach(item => {
      const li = document.createElement("li");
      li.textContent = `${item.No} - ${item.Amount}`;
      ul.appendChild(li);
    });
  };

  // Let AL know JS is ready
  if (window.Microsoft && Microsoft.Dynamics && Microsoft.Dynamics.NAV) {
    Microsoft.Dynamics.NAV.InvokeExtensibilityMethod("OnJsReady", []);
  }
})();
