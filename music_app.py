import tkinter as tk
from tkinter import ttk, messagebox
import subprocess, sys, threading, json, vlc, requests, webbrowser

YT = [sys.executable, "-m", "yt_dlp", "--remote-components", "ejs:github"]
ITUNES = "https://itunes.apple.com"
player = vlc.MediaPlayer()


def yt_find(query):
    r = subprocess.run(YT + [f"ytsearch3:{query}", "--flat-playlist", "--dump-json"],
                       capture_output=True, text=True)
    if r.returncode != 0:
        return None
    for line in r.stdout.strip().splitlines():
        if line.strip():
            try:
                return json.loads(line)["id"]
            except:
                continue
    return None


class App:
    def __init__(self):
        self.root = tk.Tk()
        self.root.title("tmp3 - music player")
        self.root.geometry("800x600")
        self.root.minsize(600, 400)
        self.is_paused = False
        self.cur = ""
        self._ui()
        self.root.protocol("WM_DELETE_WINDOW", self._close)

    def _ui(self):
        top = ttk.Frame(self.root, padding=10)
        top.pack(fill=tk.X)
        ttk.Label(top, text="Search:", font=("Segoe UI", 11)).pack(side=tk.LEFT)
        self.e = ttk.Entry(top, font=("Segoe UI", 11))
        self.e.pack(side=tk.LEFT, fill=tk.X, expand=True, padx=(5, 5))
        self.e.bind("<Return>", lambda e: self._go())
        self.b = ttk.Button(top, text="Search", command=self._go)
        self.b.pack(side=tk.RIGHT)

        p = ttk.PanedWindow(self.root, orient=tk.VERTICAL)
        p.pack(fill=tk.BOTH, expand=True, padx=10, pady=(0, 10))
        f0 = ttk.LabelFrame(p, text="Results", padding=5)
        p.add(f0, weight=1)

        self.t = ttk.Treeview(f0, columns=("a","b","c"), show="tree headings", selectmode="browse")
        self.t.heading("#0", text="")
        self.t.heading("a", text="Name")
        self.t.heading("b", text="Type")
        self.t.heading("c", text="Details")
        self.t.column("#0", width=30, stretch=False)
        self.t.column("a", width=350)
        self.t.column("b", width=80)
        self.t.column("c", width=250)
        self.t.bind("<Double-1>", lambda e: self._click())
        sb = ttk.Scrollbar(f0, orient=tk.VERTICAL, command=self.t.yview)
        self.t.configure(yscrollcommand=sb.set)
        self.t.pack(side=tk.LEFT, fill=tk.BOTH, expand=True)
        sb.pack(side=tk.RIGHT, fill=tk.Y)

        f1 = ttk.LabelFrame(p, text="Now Playing", padding=10)
        p.add(f1, weight=0)
        self.st = ttk.Label(f1, text="No track loaded", font=("Segoe UI", 10))
        self.st.pack(anchor=tk.W)
        br = ttk.Frame(f1)
        br.pack(fill=tk.X, pady=(5, 0))
        self.pp = ttk.Button(br, text="Play", command=self._toggle, state=tk.DISABLED)
        self.pp.pack(side=tk.LEFT, padx=(0, 5))
        self.ss = ttk.Button(br, text="Stop", command=self._stop, state=tk.DISABLED)
        self.ss.pack(side=tk.LEFT)

    def _go(self):
        q = self.e.get().strip()
        if not q:
            return
        self.b.config(state=tk.DISABLED, text="Searching...")
        for i in self.t.get_children():
            self.t.delete(i)
        threading.Thread(target=self._sthread, args=(q,), daemon=True).start()

    def _sthread(self, q):
        seen = set()
        rows = []
        try:
            r = requests.get(f"{ITUNES}/search", params={"term": q, "entity": "musicArtist", "limit": 5}, timeout=10)
            for x in r.json().get("results", []):
                aid = f"a_{x['artistId']}"
                if aid not in seen:
                    seen.add(aid)
                    rows.append(("", aid, "", (x["artistName"], "Artist", ""), ("artist", str(x["artistId"]))))
        except:
            pass
        try:
            r = requests.get(f"{ITUNES}/search", params={"term": q, "entity": "album", "limit": 10}, timeout=10)
            for x in r.json().get("results", []):
                alid = f"al_{x['collectionId']}"
                if alid not in seen:
                    seen.add(alid)
                    parent = f"a_{x['artistId']}" if f"a_{x['artistId']}" in seen else ""
                    artist = x.get("artistName", "")
                    rows.append((parent, alid, "", (x["collectionName"], "Album", artist), ("album", str(x["collectionId"]))))
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
                    parent = f"al_{x['collectionId']}" if f"al_{x['collectionId']}" in seen else ""
                    artist = x.get("artistName", "")
                    rows.append((parent, tid, "", (x["trackName"], "Track", f"{artist} \u00b7 {m}:{s:02d}"),
                                ("track", str(x["trackId"]), x["trackName"], artist, str(x.get("collectionId","")))))
        except:
            pass
        self.root.after(0, self._show, rows)

    def _show(self, rows):
        self.b.config(state=tk.NORMAL, text="Search")
        for parent, iid, text, vals, tags in rows:
            self.t.insert(parent, tk.END, iid=iid, text=text, values=vals, tags=tags)

    def _click(self):
        sel = self.t.selection()
        if not sel:
            return
        tags = self.t.item(sel[0], "tags")
        if not tags:
            return
        typ = tags[0]
        if typ == "artist":
            threading.Thread(target=self._artist_thread, args=(tags[1],), daemon=True).start()
        elif typ == "album":
            threading.Thread(target=self._album_thread, args=(tags[1],), daemon=True).start()
        elif typ == "track":
            self._play(tags[2], tags[3])

    def _artist_thread(self, aid):
        try:
            r = requests.get(f"{ITUNES}/lookup", params={"id": aid, "entity": "album"}, timeout=10)
            items = r.json().get("results", [])[1:]
        except:
            items = []
        self.root.after(0, self._show_albums, items)

    def _show_albums(self, items):
        sel = self.t.selection()
        if not sel:
            return
        parent = sel[0]
        for c in self.t.get_children(parent):
            self.t.delete(c)
        for x in items:
            alid = f"al_{x['collectionId']}"
            self.t.insert(parent, tk.END, iid=alid, text="",
                          values=(x["collectionName"], "Album", f"{x.get('trackCount',0)} tracks"),
                          tags=("album", str(x["collectionId"])))
        self.t.item(parent, open=True)

    def _album_thread(self, alid):
        try:
            r = requests.get(f"{ITUNES}/lookup", params={"id": alid, "entity": "song"}, timeout=10)
            items = r.json().get("results", [])[1:]
        except:
            items = []
        self.root.after(0, self._show_tracks, items)

    def _show_tracks(self, items):
        sel = self.t.selection()
        if not sel:
            return
        parent = sel[0]
        for c in self.t.get_children(parent):
            self.t.delete(c)
        for x in items:
            tid = f"t_{x['trackId']}"
            dur = x.get("trackTimeMillis", 0) // 1000
            m, s = divmod(dur, 60)
            self.t.insert(parent, tk.END, iid=tid, text="",
                          values=(x["trackName"], "Track", f"{m}:{s:02d}"),
                          tags=("track", str(x["trackId"]), x["trackName"],
                                x["artistName"], str(x.get("collectionId",""))))
        self.t.item(parent, open=True)

    def _play(self, title, artist):
        q = f"{artist} {title} audio"
        self.cur = f"{artist} - {title}"
        self.st.config(text=f"Finding: {self.cur}...")
        self._stop()
        threading.Thread(target=self._play_thread, args=(q,), daemon=True).start()

    def _play_thread(self, q):
        vid = yt_find(q)
        if not vid:
            self.root.after(0, self._err, "No YouTube match.")
            return
        r = subprocess.run(YT + [f"https://youtube.com/watch?v={vid}", "-f", "bestaudio", "--get-url"],
                           capture_output=True, text=True)
        if r.returncode != 0 or not r.stdout.strip():
            self.root.after(0, self._err, f"Stream error:\n{r.stderr[-200:]}")
            return
        self.root.after(0, self._stream, r.stdout.strip().split("\n")[-1])

    def _stream(self, url):
        try:
            player.stop()
            player.set_media(vlc.Media(url))
            player.play()
            self.is_paused = False
            self.pp.config(text="Pause", state=tk.NORMAL)
            self.ss.config(state=tk.NORMAL)
            self.st.config(text=f"Playing: {self.cur}")
        except Exception as e:
            self._err(str(e))

    def _err(self, msg):
        messagebox.showerror("Error", msg)
        self.st.config(text="Error")

    def _toggle(self):
        if self.is_paused:
            player.play()
            self.is_paused = False
            self.pp.config(text="Pause")
            self.st.config(text=f"Playing: {self.cur}")
        else:
            player.pause()
            self.is_paused = True
            self.pp.config(text="Resume")
            self.st.config(text="Paused")

    def _stop(self):
        player.stop()
        self.is_paused = False
        self.pp.config(text="Play", state=tk.DISABLED)
        self.ss.config(state=tk.DISABLED)
        self.st.config(text="Stopped")

    def _close(self):
        player.stop()
        self.root.destroy()

    def run(self):
        self.root.mainloop()


if __name__ == "__main__":
    App().run()
