import tkinter as tk
from tkinter import ttk, messagebox
import subprocess, sys, threading, json, vlc, requests, time

YT = [sys.executable, "-m", "yt_dlp", "--remote-components", "ejs:github"]
ITUNES = "https://itunes.apple.com"
player = vlc.MediaPlayer()
player.audio_set_volume(80)
track_data = {}


def yt_find(query):
    r = subprocess.run(YT + [f"ytsearch3:{query}", "--flat-playlist", "--dump-json"],
                       capture_output=True, text=True, timeout=30)
    if r.returncode != 0:
        return None
    for line in r.stdout.strip().splitlines():
        if line.strip():
            try:
                return json.loads(line)["id"]
            except:
                continue
    return None


def yt_stream(vid):
    r = subprocess.run(YT + [f"https://youtube.com/watch?v={vid}", "-f", "bestaudio", "--get-url"],
                       capture_output=True, text=True, timeout=30)
    if r.returncode != 0 or not r.stdout.strip():
        return None
    return r.stdout.strip().split("\n")[-1]


class App:
    def __init__(self):
        self.root = tk.Tk()
        self.root.title("tmp3 - music player")
        self.root.geometry("950x650")
        self.root.minsize(700, 500)

        self.queue = []
        self.qidx = -1
        self.paused = False
        self.seeking = False

        self._ui()
        self._bind()
        self._tick()
        self.root.protocol("WM_DELETE_WINDOW", self._close)

    def _ui(self):
        top = ttk.Frame(self.root, padding=(10, 10, 10, 0))
        top.pack(fill=tk.X)
        ttk.Label(top, text="Search:").pack(side=tk.LEFT)
        self.e = ttk.Entry(top)
        self.e.pack(side=tk.LEFT, fill=tk.X, expand=True, padx=(5, 5))
        self.e.bind("<Return>", lambda e: self._go())
        self.b = ttk.Button(top, text="Search", command=self._go)
        self.b.pack(side=tk.RIGHT)

        mid = ttk.PanedWindow(self.root, orient=tk.HORIZONTAL)
        mid.pack(fill=tk.BOTH, expand=True, padx=10, pady=(5, 0))

        f0 = ttk.LabelFrame(mid, text="Results", padding=5)
        mid.add(f0, weight=1)
        self.t = ttk.Treeview(f0, columns=("a", "b", "c"), show="tree headings", selectmode="browse")
        self.t.heading("#0", text="")
        self.t.heading("a", text="Name")
        self.t.heading("b", text="Type")
        self.t.heading("c", text="Details")
        self.t.column("#0", width=30, stretch=False)
        self.t.column("a", width=300)
        self.t.column("b", width=70)
        self.t.column("c", width=200)
        sb = ttk.Scrollbar(f0, orient=tk.VERTICAL, command=self.t.yview)
        self.t.configure(yscrollcommand=sb.set)
        self.t.pack(side=tk.LEFT, fill=tk.BOTH, expand=True)
        sb.pack(side=tk.RIGHT, fill=tk.Y)

        f1 = ttk.LabelFrame(mid, text="Queue", padding=5)
        mid.add(f1, weight=1)
        qf = ttk.Frame(f1)
        qf.pack(fill=tk.BOTH, expand=True)
        self.q = tk.Listbox(qf, font=("Segoe UI", 9), selectmode=tk.SINGLE,
                            activestyle="none", bg="#f5f5f5")
        self.q.pack(side=tk.LEFT, fill=tk.BOTH, expand=True)
        sb2 = ttk.Scrollbar(qf, orient=tk.VERTICAL, command=self.q.yview)
        self.q.configure(yscrollcommand=sb2.set)
        sb2.pack(side=tk.RIGHT, fill=tk.Y)
        qbf = ttk.Frame(f1)
        qbf.pack(fill=tk.X, pady=(4, 0))
        ttk.Button(qbf, text="Play", command=self._jump_q, width=6).pack(side=tk.LEFT)
        ttk.Button(qbf, text="Remove", command=self._rm_q, width=8).pack(side=tk.LEFT, padx=(5, 0))
        ttk.Button(qbf, text="Clear", command=self._clr_q, width=6).pack(side=tk.LEFT, padx=(5, 0))

        bot = ttk.Frame(self.root, padding=(10, 5, 10, 10))
        bot.pack(fill=tk.X)

        self.st = ttk.Label(bot, text="No track loaded")
        self.st.pack(anchor=tk.W)

        ctrl = ttk.Frame(bot)
        ctrl.pack(fill=tk.X, pady=(3, 0))
        self.prv = ttk.Button(ctrl, text="|<", width=3, command=self._prev, state=tk.DISABLED)
        self.prv.pack(side=tk.LEFT, padx=(0, 2))
        self.pp = ttk.Button(ctrl, text=">", width=3, command=self._toggle, state=tk.DISABLED)
        self.pp.pack(side=tk.LEFT, padx=2)
        self.nxt = ttk.Button(ctrl, text=">|", width=3, command=self._next, state=tk.DISABLED)
        self.nxt.pack(side=tk.LEFT, padx=2)
        self.ss = ttk.Button(ctrl, text="[]", width=3, command=self._stop, state=tk.DISABLED)
        self.ss.pack(side=tk.LEFT, padx=(2, 10))

        ttk.Label(ctrl, text="Vol:").pack(side=tk.LEFT)
        self.vol = ttk.Scale(ctrl, from_=0, to=100, orient=tk.HORIZONTAL,
                             value=80, command=lambda v: player.audio_set_volume(int(float(v))),
                             length=100)
        self.vol.pack(side=tk.LEFT, padx=(3, 10))
        self.tl = ttk.Label(ctrl, text="0:00 / 0:00")
        self.tl.pack(side=tk.RIGHT)

        skf = ttk.Frame(bot)
        skf.pack(fill=tk.X, pady=(3, 0))
        self.sk = ttk.Scale(skf, from_=0, to=1000, orient=tk.HORIZONTAL, value=0)
        self.sk.pack(fill=tk.X)

    def _bind(self):
        self.t.bind("<Double-1>", self._on_dbl)
        self.sk.bind("<ButtonPress-1>", lambda e: setattr(self, 'seeking', True))
        self.sk.bind("<ButtonRelease-1>", self._seek_done)
        em = player.event_manager()
        em.event_attach(vlc.EventType.MediaPlayerEndReached, lambda e: self.root.after(0, self._auto_nxt))

    def _go(self):
        q = self.e.get().strip()
        if not q:
            return
        self.b.config(state=tk.DISABLED, text="Searching...")
        for i in self.t.get_children():
            self.t.delete(i)
        track_data.clear()
        threading.Thread(target=self._search, args=(q,), daemon=True).start()

    def _search(self, q):
        rows = []
        seen = set()
        try:
            r = requests.get(f"{ITUNES}/search", params={"term": q, "entity": "musicArtist", "limit": 5}, timeout=10)
            for x in r.json().get("results", []):
                aid = f"a_{x['artistId']}"
                if aid not in seen:
                    seen.add(aid)
                    rows.append(("", aid, "", (x["artistName"], "Artist", ""), ("artist", x["artistId"])))
        except:
            pass
        try:
            r = requests.get(f"{ITUNES}/search", params={"term": q, "entity": "album", "limit": 10}, timeout=10)
            for x in r.json().get("results", []):
                alid = f"al_{x['collectionId']}"
                if alid not in seen:
                    seen.add(alid)
                    p = f"a_{x['artistId']}" if f"a_{x['artistId']}" in seen else ""
                    rows.append((p, alid, "", (x["collectionName"], "Album", x.get("artistName","")), ("album", x["collectionId"])))
        except:
            pass
        try:
            r = requests.get(f"{ITUNES}/search", params={"term": q, "entity": "song", "limit": 15}, timeout=10)
            for x in r.json().get("results", []):
                tid = f"t_{x['trackId']}"
                if tid not in seen:
                    seen.add(tid)
                    dur = x.get("trackTimeMillis", 0) // 1000
                    m, s = divmod(dur, 60)
                    p = f"al_{x['collectionId']}" if f"al_{x['collectionId']}" in seen else ""
                    track_data[tid] = (x["trackName"], x["artistName"], str(x.get("collectionId","")))
                    rows.append((p, tid, "", (x["trackName"], "Track", f"{x['artistName']} \u00b7 {m}:{s:02d}"), ("track", tid)))
        except:
            pass
        self.root.after(0, self._show, rows)

    def _show(self, rows):
        self.b.config(state=tk.NORMAL, text="Search")
        for p, iid, txt, vals, tags in rows:
            try:
                self.t.insert(p, tk.END, iid=iid, text=txt, values=vals, tags=tags)
            except:
                pass

    def _on_dbl(self, event):
        sel = self.t.selection()
        if not sel:
            return
        iid = sel[0]
        tags = self.t.item(iid, "tags")
        if not tags:
            return
        typ = tags[0]
        rid = tags[1]
        if typ == "artist":
            threading.Thread(target=self._load_artist, args=(rid,), daemon=True).start()
        elif typ == "album":
            threading.Thread(target=self._load_album, args=(rid,), daemon=True).start()
        elif typ == "track":
            info = track_data.get(rid)
            if info:
                self._enqueue(info[0], info[1], info[2])

    def _load_artist(self, aid):
        try:
            r = requests.get(f"{ITUNES}/lookup", params={"id": aid, "entity": "album"}, timeout=10)
            items = r.json().get("results", [])[1:]
        except:
            items = []
        self.root.after(0, self._show_artist, items)

    def _show_artist(self, items):
        sel = self.t.selection()
        if not sel:
            return
        pid = sel[0]
        for c in self.t.get_children(pid):
            self.t.delete(c)
        for x in items:
            alid = f"al_{x['collectionId']}"
            try:
                self.t.insert(pid, tk.END, iid=alid, text="",
                              values=(x["collectionName"], "Album", f"{x.get('trackCount',0)} tracks"),
                              tags=("album", x["collectionId"]))
            except:
                pass
        self.t.item(pid, open=True)

    def _load_album(self, alid):
        try:
            r = requests.get(f"{ITUNES}/lookup", params={"id": alid, "entity": "song"}, timeout=10)
            items = r.json().get("results", [])[1:]
        except:
            items = []
        self.root.after(0, self._show_album, items)

    def _show_album(self, items):
        sel = self.t.selection()
        if not sel:
            return
        pid = sel[0]
        for c in self.t.get_children(pid):
            self.t.delete(c)
        for x in items:
            tid = f"t_{x['trackId']}"
            dur = x.get("trackTimeMillis", 0) // 1000
            m, s = divmod(dur, 60)
            track_data[tid] = (x["trackName"], x["artistName"], str(x.get("collectionId","")))
            try:
                self.t.insert(pid, tk.END, iid=tid, text="",
                              values=(x["trackName"], "Track", f"{m}:{s:02d}"),
                              tags=("track", tid))
            except:
                pass
        self.t.item(pid, open=True)

    def _enqueue(self, title, artist, album):
        item = type("Item", (), {"title": title, "artist": artist, "album": album, "query": f"{artist} {title}"})()
        self.queue.append(item)
        self.q.insert(tk.END, f"{artist} - {title}")
        self.qidx = len(self.queue) - 1
        self.q.selection_clear(0, tk.END)
        self.q.selection_set(self.qidx)
        self._update_nav()
        self._play_q()

    def _play_q(self):
        if self.qidx < 0 or self.qidx >= len(self.queue):
            return
        item = self.queue[self.qidx]
        self.st.config(text=f"Loading: {item.artist} - {item.title}...")
        self._stop()
        threading.Thread(target=self._play_thr, args=(item,), daemon=True).start()

    def _play_thr(self, item):
        try:
            vid = yt_find(item.query)
            if not vid:
                self.root.after(0, self._err, f"No YouTube match for {item.title}")
                return
            url = yt_stream(vid)
            if not url:
                self.root.after(0, self._err, f"Stream error for {item.title}")
                return
            self.root.after(0, self._play_vlc, url, item)
        except Exception as e:
            self.root.after(0, self._err, str(e))

    def _update_nav(self):
        has = len(self.queue) > 0 and self.qidx >= 0 and self.qidx < len(self.queue)
        if has:
            self.prv.config(state=tk.NORMAL if self.qidx > 0 else tk.DISABLED)
            self.nxt.config(state=tk.NORMAL if self.qidx < len(self.queue) - 1 else tk.DISABLED)
        else:
            self.prv.config(state=tk.DISABLED)
            self.nxt.config(state=tk.DISABLED)

    def _play_vlc(self, url, item):
        try:
            player.stop()
            player.set_media(vlc.Media(url))
            player.play()
            self.paused = False
            self.pp.config(text="||", state=tk.NORMAL)
            self.ss.config(state=tk.NORMAL)
            self._update_nav()
            self.st.config(text=f"Playing: {item.artist} - {item.title}")
            self.q.selection_clear(0, tk.END)
            self.q.selection_set(self.qidx)
            self.q.see(self.qidx)
        except Exception as e:
            self._err(str(e))

    def _toggle(self):
        if self.paused:
            player.play()
            self.paused = False
            self.pp.config(text="||")
            self.st.config(text="Playing")
        else:
            player.pause()
            self.paused = True
            self.pp.config(text=">")
            self.st.config(text="Paused")

    def _stop(self):
        player.stop()
        self.paused = False
        self.pp.config(text=">", state=tk.DISABLED)
        self.ss.config(state=tk.DISABLED)
        self._update_nav()
        self.sk.set(0)
        self.tl.config(text="0:00 / 0:00")

    def _prev(self):
        if self.qidx > 0:
            self.qidx -= 1
            self._play_q()

    def _next(self):
        if self.qidx < len(self.queue) - 1:
            self.qidx += 1
            self._play_q()

    def _auto_nxt(self):
        if self.qidx < len(self.queue) - 1:
            self.qidx += 1
            self._play_q()
        else:
            self._stop()

    def _jump_q(self):
        sel = self.q.curselection()
        if sel:
            self.qidx = sel[0]
            self._play_q()

    def _rm_q(self):
        sel = self.q.curselection()
        if not sel:
            return
        i = sel[0]
        self.q.delete(i)
        self.queue.pop(i)
        if not self.queue:
            self.qidx = -1
            self._stop()
        elif i <= self.qidx:
            self.qidx = max(0, self.qidx - 1)
            self.q.selection_set(self.qidx)
        self._update_nav()

    def _clr_q(self):
        self.queue.clear()
        self.q.delete(0, tk.END)
        self.qidx = -1
        self._stop()
        self._update_nav()

    def _seek_done(self, event):
        self.seeking = False
        length = player.get_length()
        if length > 0:
            v = float(self.sk.get()) / 1000.0
            player.set_time(int(v * length))

    def _tick(self):
        try:
            if not self.seeking and player.is_playing():
                length = player.get_length()
                cur = player.get_time()
                if length > 0:
                    pct = min(1000, int(cur / length * 1000))
                    self.sk.set(pct)
                    cs, ls = int(cur / 1000), int(length / 1000)
                    self.tl.config(text=f"{cs//60}:{cs%60:02d} / {ls//60}:{ls%60:02d}")
        except:
            pass
        self.root.after(500, self._tick)

    def _err(self, msg):
        messagebox.showerror("Error", msg)
        self.st.config(text="Error")

    def _close(self):
        player.stop()
        self.root.destroy()

    def run(self):
        self.root.mainloop()


if __name__ == "__main__":
    App().run()
