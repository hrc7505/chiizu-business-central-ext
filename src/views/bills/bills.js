window.onload = function () {
  const container = document.createElement('div');
  container.id = 'bills-container';
  container.innerHTML = `
    <h2>Bills</h2>
    <ul>
      <li>Example 1</li>
      <li>Example 2</li>
    </ul>
  `;
  document.body.appendChild(container);
};
