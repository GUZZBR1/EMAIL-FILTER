import { render, screen } from "@testing-library/react";
import { describe, it, expect } from "vitest";
import HomePage from "../src/app/page";
import HealthPage from "../src/app/health/page";

describe("HomePage", () => {
  it("should render the title Email Filter", () => {
    render(<HomePage />);
    expect(screen.getByText(/Email Filter/i)).toBeInTheDocument();
  });

  it("should indicate the project is in foundation state", () => {
    render(<HomePage />);
    expect(screen.getByText(/fundação em andamento/i)).toBeInTheDocument();
  });
});

describe("HealthPage", () => {
  it("should render status ok", () => {
    render(<HealthPage />);
    expect(screen.getByText(/status/i)).toBeInTheDocument();
    expect(screen.getByText(/ok/i)).toBeInTheDocument();
  });

  it("should render service name email-filter-web", () => {
    render(<HealthPage />);
    expect(screen.getByText(/email-filter-web/i)).toBeInTheDocument();
  });
});
