// OrchardEye landing. Progressive enhancement only.

const revealEls = document.querySelectorAll(".reveal");

if ("IntersectionObserver" in window) {
  const io = new IntersectionObserver(
    (entries) => {
      for (const entry of entries) {
        if (entry.isIntersecting) {
          entry.target.classList.add("is-in");
          io.unobserve(entry.target);
        }
      }
    },
    { threshold: 0.12, rootMargin: "0px 0px -8% 0px" },
  );

  revealEls.forEach((el) => {
    const siblings = Array.from(el.parentElement?.children || []);
    const index = siblings.indexOf(el);
    el.style.transitionDelay = `${Math.min(Math.max(index, 0), 4) * 70}ms`;
    io.observe(el);
  });
} else {
  revealEls.forEach((el) => el.classList.add("is-in"));
}

const nav = document.getElementById("nav");
const navToggle = document.getElementById("navToggle");

if (nav) {
  const onScroll = () => {
    nav.classList.toggle("is-stuck", window.scrollY > 8);
  };

  onScroll();
  window.addEventListener("scroll", onScroll, { passive: true });
}

if (nav && navToggle) {
  const menu = nav.querySelector(".nav__links");
  const setOpen = (open) => {
    nav.classList.toggle("is-open", open);
    navToggle.setAttribute("aria-expanded", String(open));
    navToggle.setAttribute("aria-label", open ? "Close menu" : "Open menu");
  };

  navToggle.addEventListener("click", () => setOpen(!nav.classList.contains("is-open")));
  menu?.addEventListener("click", (event) => {
    if (event.target instanceof HTMLAnchorElement) setOpen(false);
  });
  document.addEventListener("keydown", (event) => {
    if (event.key === "Escape") setOpen(false);
  });
  document.addEventListener("click", (event) => {
    if (!nav.contains(event.target)) setOpen(false);
  });
}

const form = document.getElementById("pilotForm");

if (form instanceof HTMLFormElement) {
  const status = form.querySelector(".pilot__status");
  const setStatus = (message, ok) => {
    if (!status) return;
    status.textContent = message;
    status.dataset.state = ok ? "ok" : "err";
  };

  form.addEventListener("submit", async (event) => {
    event.preventDefault();
    const data = Object.fromEntries(new FormData(form).entries());
    const name = String(data.name || "").trim();
    const email = String(data.email || "").trim();

    if (!name || !/^[^@\s]+@[^@\s]+\.[^@\s]+$/.test(email)) {
      setStatus("Add your name and a valid email first.", false);
      return;
    }

    const endpoint = form.dataset.endpoint?.trim();
    if (endpoint) {
      try {
        const response = await fetch(endpoint, {
          method: "POST",
          headers: { Accept: "application/json" },
          body: new FormData(form),
        });
        setStatus(
          response.ok ? "Thanks. We'll be in touch about the pilot." : "Something went wrong. Try the email link.",
          response.ok,
        );
        if (response.ok) form.reset();
      } catch {
        setStatus("Network error. Try again, or email us directly.", false);
      }
      return;
    }

    const body = [
      `Name: ${name}`,
      `Email: ${email}`,
      `Orchard: ${String(data.orchard || "").trim() || "-"}`,
      "",
      String(data.message || "").trim(),
    ].join("\n");
    const to = form.dataset.mailto || "ruchiagrawal9221@gmail.com";
    window.location.href =
      `mailto:${to}?subject=${encodeURIComponent("OrchardEye pilot application")}` +
      `&body=${encodeURIComponent(body)}`;
    setStatus("Opening your email app to send the application.", true);
  });
}

// State map
(function () {
  const data = window.OE_STATES;
  const grid = document.getElementById("usGrid");
  const card = document.getElementById("stateCard");
  if (!data || !grid || !card) return;

  const fmt = (n) => n.toLocaleString("en-US");
  const metrics = {
    scans: { label: "Apples scanned", get: (s) => s.scans, show: (v) => fmt(v), from: [233, 244, 234], to: [47, 125, 62], log: true },
    disease: { label: "Disease found", get: (s) => s.disease, show: (v) => v.toFixed(1) + "%", from: [252, 236, 233], to: [217, 72, 63] },
    brix: { label: "Average Brix", get: (s) => s.brix, show: (v) => v.toFixed(1) + "°", from: [253, 243, 222], to: [214, 132, 20] },
  };
  let metric = "scans";
  let selected = "WA";

  const tiles = {};
  data.forEach((s) => {
    const b = document.createElement("button");
    b.type = "button";
    b.className = "usmap__tile";
    b.style.gridRow = s.r + 1;
    b.style.gridColumn = s.c + 1;
    b.textContent = s.a;
    b.setAttribute("aria-label", s.n);
    b.addEventListener("click", () => select(s.a));
    b.addEventListener("mouseenter", () => render(s));
    b.addEventListener("mouseleave", () => render(byAbbr(selected)));
    grid.appendChild(b);
    tiles[s.a] = b;
  });

  function byAbbr(a) { return data.find((s) => s.a === a); }

  function paint() {
    const m = metrics[metric];
    const tx = (v) => (m.log ? Math.log10(v) : v);
    const vals = data.map((s) => tx(m.get(s)));
    const lo = Math.min(...vals), hi = Math.max(...vals);
    data.forEach((s) => {
      const t = hi === lo ? 0.5 : (tx(m.get(s)) - lo) / (hi - lo);
      const c = m.from.map((f, i) => Math.round(f + (m.to[i] - f) * t));
      const el = tiles[s.a];
      el.style.background = `rgb(${c.join(",")})`;
      el.style.color = t > 0.55 ? "#fff" : "var(--ink)";
      el.title = `${s.n}: ${m.show(m.get(s))}`;
    });
    const raw = data.map((s) => m.get(s));
    document.getElementById("legLo").textContent = m.show(Math.min(...raw));
    document.getElementById("legHi").textContent = m.show(Math.max(...raw));
    document.getElementById("legBar").style.background = `linear-gradient(90deg, rgb(${m.from.join(",")}), rgb(${m.to.join(",")}))`;
  }

  function render(s) {
    card.innerHTML = `
      <h3>${s.n}</h3>
      <dl>
        <div><dt>Apples scanned</dt><dd>${fmt(s.scans)}</dd></div>
        <div><dt>Growers</dt><dd>${fmt(s.growers)}</dd></div>
        <div><dt>Disease found</dt><dd>${s.disease.toFixed(1)}%</dd></div>
        <div><dt>Average Brix</dt><dd>${s.brix.toFixed(1)}°</dd></div>
        <div><dt>Ready to pick</dt><dd>${s.ready}%</dd></div>
        <div><dt>Main variety</dt><dd>${s.variety}</dd></div>
      </dl>
      <p class="usmap__top"><span>Most common disease</span><b>${s.top}</b></p>
      <div class="usmap__bar" role="img" aria-label="${s.ready}% ready to pick"><i style="width:${s.ready}%"></i></div>
      <p class="usmap__barlabel">${s.ready}% of scanned apples ready to pick</p>`;
  }

  function select(a) {
    selected = a;
    Object.values(tiles).forEach((t) => t.classList.toggle("is-on", t.textContent === a));
    render(byAbbr(a));
  }

  document.querySelectorAll(".usmap__tabs button").forEach((btn) => {
    btn.addEventListener("click", () => {
      metric = btn.dataset.metric;
      document.querySelectorAll(".usmap__tabs button").forEach((b) => b.setAttribute("aria-selected", b === btn ? "true" : "false"));
      paint();
    });
  });

  const totals = document.getElementById("usTotals");
  if (totals) {
    const scans = data.reduce((a, s) => a + s.scans, 0);
    const growers = data.reduce((a, s) => a + s.growers, 0);
    const disease = data.reduce((a, s) => a + s.disease * s.scans, 0) / scans;
    const brix = data.reduce((a, s) => a + s.brix * s.scans, 0) / scans;
    totals.innerHTML = [
      [fmt(scans), "apples scanned"],
      [fmt(growers), "growers"],
      ["50", "states"],
      [disease.toFixed(1) + "%", "disease found"],
      [brix.toFixed(1) + "°", "average Brix"],
    ].map(([b, s]) => `<div><b>${b}</b><span>${s}</span></div>`).join("");
  }

  paint();
  select(selected);
})();
