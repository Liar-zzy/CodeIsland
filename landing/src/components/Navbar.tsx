import { useState, useEffect } from "react"
import { Download } from "lucide-react"

export default function Navbar() {
  const [scrolled, setScrolled] = useState(false)

  useEffect(() => {
    const onScroll = () => setScrolled(window.scrollY > 40)
    window.addEventListener("scroll", onScroll)
    return () => window.removeEventListener("scroll", onScroll)
  }, [])

  return (
    <nav
      className={`fixed top-0 left-0 right-0 z-50 transition-all duration-500 ${
        scrolled
          ? "bg-deep/70 backdrop-blur-xl border-b border-white/[0.04]"
          : "bg-transparent"
      }`}
    >
      <div className="max-w-6xl mx-auto px-6 h-16 flex items-center justify-between">
        <a href="#" className="flex items-center gap-2 group">
          <img src="/logo.png" alt="CodeIsland" className="w-6 h-6 rounded group-hover:scale-110 transition-transform" />
          <span className="font-mono text-sm font-bold text-text-primary tracking-[0.15em]">
            CODEISLAND
          </span>
        </a>

        <div className="flex items-center gap-8">
          <div className="hidden md:flex items-center gap-6 text-sm text-text-muted">
            {["Demo", "Features", "How it Works", "GitHub"].map((item) => (
              <a
                key={item}
                href={`#${item.toLowerCase().replace(/ /g, "-")}`}
                className="hover:text-text-primary transition-colors relative after:absolute after:bottom-0 after:left-0 after:w-0 after:h-px after:bg-green after:transition-all hover:after:w-full"
              >
                {item}
              </a>
            ))}
          </div>
          <a
            href="https://github.com/xmqywx/CodeIsland/releases"
            className="flex items-center gap-2 bg-green/10 text-green border border-green/20 px-4 py-2 rounded-lg text-sm font-medium hover:bg-green/20 hover:border-green/30 transition-all"
          >
            <Download size={14} />
            Download
          </a>
        </div>
      </div>
    </nav>
  )
}
