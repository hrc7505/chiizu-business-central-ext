
function renderList(title, jsonData, onRenderItem) {
    const containerId = "chiizu-container";
    const listId = "chiizu-list";
    console.log("DisplayList called with data:", jsonData);

    try {
        const list = JSON.parse(jsonData);
        let container = document.getElementById(containerId);

        if (!container) {
            container = document.createElement("div");
            container.id = containerId;
            container.innerHTML = `<h2>${title}</h2><ul id="${listId}"></ul>`;
            const bcRoot = document.getElementById("controlAddIn");
            bcRoot.style.overflow = "auto";
            bcRoot.appendChild(container);
        }

        const ul = document.getElementById(listId);

        list.forEach(item => {
            ul.appendChild(onRenderItem(item));
        });
    } catch (e) {
        console.error("Invalid JSON:", jsonData, e);
    }
}