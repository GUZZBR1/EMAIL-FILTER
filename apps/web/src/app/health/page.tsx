import React from "react";

export default function HealthPage() {
  return (
    <main style={{ padding: "2rem", fontFamily: "sans-serif" }}>
      <h1>Service Health</h1>
      <p>
        Status: <strong style={{ color: "green" }}>ok</strong>
      </p>
      <p>
        Service: <code>email-filter-web</code>
      </p>
    </main>
  );
}
