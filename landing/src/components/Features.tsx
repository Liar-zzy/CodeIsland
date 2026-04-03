import { Cat, Zap, ShieldCheck, Monitor, Terminal, Bell } from "lucide-react"
import type { LucideIcon } from "lucide-react"

const features: { Icon: LucideIcon; title: string; desc: string; ascii: string }[] = [
  {
    Icon: Cat,
    ascii: `/\\_/\\
( o.o )
 > ^ <`,
    title: "Pixel Cat Companion",
    desc: "6 animated states that react to your agents. Blinks idle, eyes dart working, waves when it needs you.",
  },
  {
    Icon: Zap,
    ascii: `  [*]
  /|\\
 / | \\`,
    title: "Zero Config",
    desc: "One launch, done. Auto-installs hooks into Claude Code and starts monitoring all sessions.",
  },
  {
    Icon: ShieldCheck,
    ascii: ` [+3 -1]
 ───────
  allow`,
    title: "Notch Approval",
    desc: "Approve or deny permissions with full code diff preview, right from the notch.",
  },
  {
    Icon: Monitor,
    ascii: `[● ● ●]
[  ...  ]
[_______]`,
    title: "Session Monitor",
    desc: "See every running Claude Code session — tool calls, duration, status — at a glance.",
  },
  {
    Icon: Terminal,
    ascii: `  > _
 cmux
  > _`,
    title: "Terminal Jump",
    desc: "Jump to the exact terminal tab and split pane. Works with cmux, iTerm2, and more.",
  },
  {
    Icon: Bell,
    ascii: `  .-.
 | ! |
  '-'`,
    title: "Sound Alerts",
    desc: "8-bit synthesized sounds for every event. Import custom sound packs or craft your own.",
  },
]

export default function Features() {
  return (
    <section id="features" className="relative py-32 px-6 noise">
      <div className="absolute inset-0 bg-[radial-gradient(ellipse_80%_50%_at_50%_0%,rgba(124,58,237,0.06)_0%,transparent_60%)]" />

      <div className="max-w-6xl mx-auto relative z-10">
        <div
          style={{ animation: 'heroEnter 0.8s ease-out both' }}
          className="text-center mb-20"
        >
          <span className="font-mono text-xs text-green uppercase tracking-[0.3em]">capabilities</span>
          <h2 className="font-display text-4xl sm:text-5xl font-extrabold text-text-primary mt-4">
            Everything in the notch
          </h2>
        </div>

        <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 gap-6">
          {features.map((f, i) => (
            <div
              key={f.title}
              style={{ animation: `heroEnter 0.6s ease-out ${i * 0.08}s both` }}
              className="group glass rounded-2xl p-7 transition-all duration-500 hover:translate-y-[-4px] hover:shadow-[0_20px_60px_rgba(124,58,237,0.08)]"
            >
              {/* Icon + ASCII side by side */}
              <div className="flex items-start justify-between mb-5">
                <div className="w-10 h-10 rounded-xl bg-green/10 border border-green/15 flex items-center justify-center">
                  <f.Icon size={18} className="text-green" />
                </div>
                <pre className="font-mono text-[10px] leading-tight text-purple-light/30 group-hover:text-green/40 transition-colors duration-500 text-right">
                  {f.ascii}
                </pre>
              </div>

              <h3 className="font-display text-lg font-bold text-text-primary group-hover:text-green transition-colors duration-300">
                {f.title}
              </h3>
              <p className="text-sm text-text-muted mt-2 leading-relaxed">
                {f.desc}
              </p>
            </div>
          ))}
        </div>
      </div>
    </section>
  )
}
