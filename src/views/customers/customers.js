(function () {
  // Only call OnJsReady once
  if (window._controlInitialized) return;
  window._controlInitialized = true;

  window.DisplayList = function (title, jsonData) {
    renderList(title, jsonData, (item) => {
      const li = document.createElement("li");
      li.textContent = `${item.No} - ${item.Name}`;

      return li
    })
    /* console.log("DisplayList called with data:", jsonData);

    try {
      const list = JSON.parse(jsonData);
      let container = document.getElementById(containerId);

      if (!container) {
        container = document.createElement("div");
        container.id = containerId;

        container.innerHTML = `<h2>${title}</h2><ul id="${listId}"></ul>`;
        document.getElementById("controlAddIn").appendChild(container);
      }

      const ul = document.getElementById("listId");
      ul.innerHTML = ""; // Clear previous entries

      list.forEach(customer => {
        const li = document.createElement("li");
        li.textContent = `${customer.No} - ${customer.Name}`;
        ul.appendChild(li);
      });
    } catch (e) {
      console.error("Invalid JSON:", jsonData);
    } */
  };

  // Notify AL that JS is ready only once
  if (window.Microsoft && Microsoft.Dynamics && Microsoft.Dynamics.NAV) {
    Microsoft.Dynamics.NAV.InvokeExtensibilityMethod("OnJsReady", []);
  }
})();