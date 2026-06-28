import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["testStatusChart", "bugPriorityChart", "bugStatusChart"]
  static values = {
    testStats: Object,
    bugPriorityStats: Object,
    bugStatusStats: Object
  }

  connect() {
    // Dark-theme defaults for Chart.js (readable on dark surfaces)
    if (window.Chart) {
      window.Chart.defaults.color = "#a1a1aa"
      window.Chart.defaults.borderColor = "rgba(255, 255, 255, 0.06)"
    }
    this.renderTestStatusChart()
    this.renderBugPriorityChart()
    this.renderBugStatusChart()
  }

  disconnect() {
    this.destroyCharts()
  }

  destroyCharts() {
    if (this.testStatusChartInstance) this.testStatusChartInstance.destroy()
    if (this.bugPriorityChartInstance) this.bugPriorityChartInstance.destroy()
    if (this.bugStatusChartInstance) this.bugStatusChartInstance.destroy()
  }

  renderTestStatusChart() {
    if (!this.hasTestStatusChartTarget) return

    const stats = this.testStatsValue
    const ctx = this.testStatusChartTarget.getContext("2d")
    
    this.testStatusChartInstance = new window.Chart(ctx, {
      type: "doughnut",
      data: {
        labels: ["Pass", "Fail", "Not Run", "Unknown"],
        datasets: [{
          data: [
            stats.pass || 0,
            stats.fail || 0,
            stats.not_run || 0,
            stats.unknown || 0
          ],
          backgroundColor: ["#198754", "#dc3545", "#6c757d", "#ffc107"],
          borderWidth: 1
        }]
      },
      options: {
        responsive: true,
        maintainAspectRatio: false,
        plugins: {
          legend: { position: "right" }
        }
      }
    })
  }

  renderBugPriorityChart() {
    if (!this.hasBugPriorityChartTarget) return

    const stats = this.bugPriorityStatsValue
    const ctx = this.bugPriorityChartTarget.getContext("2d")

    this.bugPriorityChartInstance = new window.Chart(ctx, {
      type: "bar",
      data: {
        labels: ["High", "Normal", "Low"],
        datasets: [{
          label: "Bugs",
          data: [
            stats.high || 0,
            stats.normal || 0,
            stats.low || 0
          ],
          backgroundColor: ["#dc3545", "#fd7e14", "#0dcaf0"],
          borderWidth: 1
        }]
      },
      options: {
        responsive: true,
        maintainAspectRatio: false,
        scales: {
          y: {
            beginAtZero: true,
            ticks: { stepSize: 1, color: "#a1a1aa" },
            grid: { color: "rgba(255, 255, 255, 0.06)" }
          },
          x: {
            ticks: { color: "#a1a1aa" },
            grid: { display: false }
          }
        },
        plugins: {
          legend: { display: false }
        }
      }
    })
  }

  renderBugStatusChart() {
    if (!this.hasBugStatusChartTarget) return

    const stats = this.bugStatusStatsValue
    const ctx = this.bugStatusChartTarget.getContext("2d")

    this.bugStatusChartInstance = new window.Chart(ctx, {
      type: "pie",
      data: {
        labels: ["New", "Fixing", "Testing", "Pending", "Done"],
        datasets: [{
          data: [
            stats.new || 0,
            stats.fixing || 0,
            stats.testing || 0,
            stats.pending || 0,
            stats.done || 0
          ],
          backgroundColor: ["#0d6efd", "#ffc107", "#0dcaf0", "#6f42c1", "#198754"],
          borderWidth: 1
        }]
      },
      options: {
        responsive: true,
        maintainAspectRatio: false,
        plugins: {
          legend: { position: "right" }
        }
      }
    })
  }
}
