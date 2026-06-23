import React from "react";
import Link from "next/link";

export default function Home() {
  return (
    <main style={{ padding: "2rem", fontFamily: "sans-serif" }}>
      <h1>Email Filter</h1>
      <p>
        Frontend status: <strong>Working</strong>
      </p>
      <p>
        Project state: <em>Fundação em andamento</em>
      </p>
      <div style={{ marginTop: "1rem" }}>
        <Link
          href="/health"
          style={{ color: "blue", textDecoration: "underline" }}
        >
          Check Health
        </Link>
      </div>
    </main>
  );
}
