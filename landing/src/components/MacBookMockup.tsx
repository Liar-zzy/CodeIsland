import { useState, useEffect, useCallback } from "react"
import { motion, AnimatePresence } from "motion/react"

/**
 * A high-fidelity CSS-only MacBook screen mockup showing CodeIsland's notch UI
 * in action, similar to how vibeisland.app presents their product.
 */

type NotchState = "collapsed" | "expanded"

const TerminalWindow = ({ title, children, className = "" }: { title: string; children: React.ReactNode; className?: string }) => (
  <div className={`rounded-lg overflow-hidden border border-white/[0.08] shadow-2xl ${className}`} style={{ background: 'rgba(22,22,30,0.95)', backdropFilter: 'blur(20px)' }}>
    <div className="flex items-center gap-1.5 px-3 py-2 border-b border-white/[0.06]">
      <div className="w-2.5 h-2.5 rounded-full bg-[#ff5f57]" />
      <div className="w-2.5 h-2.5 rounded-full bg-[#febc2e]" />
      <div className="w-2.5 h-2.5 rounded-full bg-[#28c840]" />
      <span className="ml-2 font-mono text-[10px] text-white/40">{title}</span>
    </div>
    <div className="p-3 font-mono text-[11px] leading-relaxed">
      {children}
    </div>
  </div>
)

export default function MacBookMockup() {
  const [notchState, setNotchState] = useState<NotchState>("collapsed")
  const [activeSession, setActiveSession] = useState(0)

  const toggle = useCallback(() => {
    setNotchState(s => s === "collapsed" ? "expanded" : "collapsed")
  }, [])

  // Auto-toggle notch
  useEffect(() => {
    const t = setInterval(() => {
      toggle()
    }, 3500)
    return () => clearInterval(t)
  }, [toggle])

  // Cycle active session indicator
  useEffect(() => {
    const t = setInterval(() => setActiveSession(s => (s + 1) % 3), 2000)
    return () => clearInterval(t)
  }, [])

  return (
    <div className="relative w-full max-w-[900px] mx-auto" style={{ animation: 'heroEnter 1.2s ease-out 0.3s both' }}>
      {/* Screen glow */}
      <div className="absolute -inset-8 bg-[radial-gradient(ellipse_at_center,rgba(124,58,237,0.12)_0%,transparent_70%)] blur-2xl pointer-events-none" />

      {/* MacBook Screen */}
      <div className="relative rounded-xl overflow-hidden border border-white/[0.08] shadow-[0_20px_80px_rgba(0,0,0,0.6)]">
        {/* macOS-style wallpaper background */}
        <div
          className="relative w-full aspect-[16/9]"
          style={{
            background: 'linear-gradient(135deg, #1a0533 0%, #0c1445 25%, #1e3a5f 50%, #3a1d5c 75%, #1a0533 100%)',
          }}
        >
          {/* Wallpaper orbs for depth */}
          <div className="absolute top-1/4 left-1/3 w-64 h-64 rounded-full bg-purple-600/20 blur-[80px]" />
          <div className="absolute bottom-1/4 right-1/4 w-48 h-48 rounded-full bg-blue-500/15 blur-[60px]" />
          <div className="absolute top-1/2 right-1/3 w-56 h-56 rounded-full bg-pink-500/10 blur-[70px]" />

          {/* Menu bar */}
          <div className="relative flex items-center justify-between px-4 h-7" style={{ background: 'rgba(0,0,0,0.25)', backdropFilter: 'blur(20px)' }}>
            <div className="flex items-center gap-4 font-mono text-[10px] text-white/80">
              <span className="font-bold"></span>
              <span>CodeIsland</span>
              <span className="text-white/50">File</span>
              <span className="text-white/50">Edit</span>
              <span className="text-white/50">Window</span>
              <span className="text-white/50">Help</span>
            </div>

            {/* Notch area — centered, above terminals */}
            <div className="absolute left-1/2 -translate-x-1/2 top-0 z-20">
              <div
                onClick={toggle}
                className="cursor-pointer transition-all duration-500 ease-[cubic-bezier(0.4,0,0.2,1)]"
              >
                <AnimatePresence mode="wait">
                  {notchState === "collapsed" ? (
                    <motion.div
                      key="collapsed"
                      initial={{ width: 200 }}
                      animate={{ width: 200 }}
                      exit={{ width: 340 }}
                      className="bg-black rounded-b-2xl px-3 py-1 flex items-center gap-2 overflow-hidden"
                      style={{ minHeight: 28 }}
                    >
                      <img src="/logo.png" alt="" className="w-4 h-4 rounded-sm shrink-0" />
                      <span className="font-mono text-[9px] text-white/70 whitespace-nowrap">myproject</span>
                      <span className="ml-auto flex items-center gap-1">
                        <span className="w-1.5 h-1.5 rounded-full bg-green" style={{ boxShadow: '0 0 4px rgba(52,211,153,0.6)' }} />
                        <span className="font-mono text-[8px] text-white/40">3</span>
                      </span>
                    </motion.div>
                  ) : (
                    <motion.div
                      key="expanded"
                      initial={{ width: 200 }}
                      animate={{ width: 340 }}
                      exit={{ width: 200 }}
                      transition={{ duration: 0.4, ease: [0.4, 0, 0.2, 1] }}
                      className="bg-black rounded-b-2xl px-3 pt-1 pb-2.5 overflow-hidden"
                    >
                      {/* Header */}
                      <div className="flex items-center justify-between mb-1.5 pb-1 border-b border-white/[0.06]">
                        <span className="font-mono text-[8px] text-white/40">3 sessions</span>
                        <span className="font-mono text-[8px] text-white/30">⚙</span>
                      </div>
                      {/* Sessions */}
                      {[
                        { name: "fix auth bug", status: "bg-green", tool: "Bash: npm test", time: "12m" },
                        { name: "optimize queries", status: "bg-amber", tool: "Read: schema.prisma", time: "5m" },
                        { name: "deploy api", status: "bg-green", tool: "Write: routes.ts", time: "2m" },
                      ].map((s, i) => (
                        <div
                          key={s.name}
                          className={`flex items-center gap-1.5 py-1 px-1 rounded text-[9px] transition-colors ${
                            activeSession === i ? "bg-white/[0.06]" : ""
                          }`}
                        >
                          <div className={`w-1.5 h-1.5 rounded-full ${s.status} shrink-0`} />
                          <span className="text-white/80 font-medium truncate">{s.name}</span>
                          <span className="ml-auto text-white/30 font-mono text-[8px] shrink-0">{s.time}</span>
                        </div>
                      ))}
                    </motion.div>
                  )}
                </AnimatePresence>
              </div>
            </div>

            <div className="flex items-center gap-3 font-mono text-[10px] text-white/50">
              <span>Wi-Fi</span>
              <span>{new Date().toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' })}</span>
            </div>
          </div>

          {/* Terminal windows on desktop — pushed down to avoid notch overlap */}
          <div className="relative px-5 pt-16 pb-4 flex gap-3 z-10">
            {/* Terminal 1 */}
            <TerminalWindow title="claude — fix-auth-bug" className="flex-1 max-w-[55%]">
              <div>
                <span className="text-green">●</span>{" "}
                <span className="text-white/70">Let me look at the auth module.</span>
              </div>
              <div className="mt-1.5">
                <span className="text-purple-light">●</span>{" "}
                <span className="text-white/50">Searching for 6 patterns...</span>{" "}
                <span className="text-white/25 text-[9px]">(click to expand)</span>
              </div>
              <div className="mt-1.5">
                <span className="text-purple-light">●</span>{" "}
                <span className="text-white/50">Read 2 files</span>
              </div>
              <div className="mt-3 rounded border border-white/[0.06] overflow-hidden">
                <div className="bg-green/10 text-green/80 px-2 py-0.5 text-[10px]">
                  + if (!token) throw new AuthError('missing');
                </div>
                <div className="bg-red-500/10 text-red-400/80 px-2 py-0.5 text-[10px]">
                  - jwt.verify(token);
                </div>
              </div>
              <div className="mt-2">
                <span className="text-green">●</span>{" "}
                <span className="text-white/70">All checks passing.</span>
              </div>
              <div className="mt-1 text-white/20">
                <span className="animate-pulse">▊</span>
              </div>
            </TerminalWindow>

            {/* Terminal 2 */}
            <TerminalWindow title="claude — optimize-queries" className="flex-1 max-w-[45%]">
              <div>
                <span className="text-amber">●</span>{" "}
                <span className="text-white/70">Analyzing the slow queries.</span>
              </div>
              <div className="mt-1.5">
                <span className="text-purple-light">●</span>{" "}
                <span className="text-white/50">Read(schema.prisma)</span>
              </div>
              <div className="mt-1.5 text-white/40 text-[10px]">
                — 2.3 MB
              </div>
              <div className="mt-1.5">
                <span className="text-purple-light">●</span>{" "}
                <span className="text-white/50">Edit(src/db/queries.ts)</span>
              </div>
              <div className="mt-2 text-white/20">
                <span className="animate-pulse">▊</span>
              </div>
            </TerminalWindow>
          </div>
        </div>
      </div>
    </div>
  )
}
