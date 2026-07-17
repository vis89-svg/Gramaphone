import tkinter as tk
from tkinter import ttk, messagebox, filedialog
import subprocess, sys, threading, json, vlc, requests, time, os, io, random
from PIL import Image, ImageTk
import urllib.request
import customtkinter as ctk

ctk.set_appearance_mode("dark")
ctk.set_default_color_theme("green")

YT = [sys.executable, "-m", "yt_dlp", "--remote-components", "ejs:github"]
ITUNES = "https://itunes.apple.com"

player = vlc.MediaPlayer()
player.audio_set_volume(80)
track_data = {}
art_cache = {}


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


def fetch_art(url, size=(80, 80)):
    if url in art_cache:
        return art_cache[url]
    try:
        data = urllib.request.urlopen(url, timeout=5).read()
        img = Image.open(io.BytesIO(data)).resize(size, Image.LANCZOS)
        photo = ctk.CTkImage(light_image=img, dark_image=img, size=size)
        art_cache[url] = photo
        return photo
    except:
        return None


class App:
    def __init__(self):
        self.root = ctk.CTk()
        self.root.title("tmp3")
        self.root.geometry("1100x700")
        self.root.minsize(850, 550)

        self.queue = []
        self.qidx = -1
        self.paused = False
        self.seeking = False
        self.repeat = 0
        self.shuffle = False
        self.shuffled_indices = []
        self.shuffle_pos = 0
        self.now_playing = None

        self._ui()
        self._bind()
        self._tick()
        self.root.protocol("WM_DELETE_WINDOW", self._close)

    def _ui(self):
        self.root.grid_columnconfigure(0, weight=0, minsize=180)
        self.root.grid_columnconfigure(1, weight=1)
        self.root.grid_rowconfigure(0, weight=1)
        self.root.grid_rowconfigure(1, weight=0, minsize=90)

        self._sidebar()
        self._main()
        self._player_bar()

    def _sidebar(self):
        side = ctk.CTkFrame(self.root, width=180, corner_radius=0)
        side.grid(row=0, column=0, rowspan=2, sticky="nsew")
        side.grid_propagate(False)

        ctk.CTkLabel(side, text="tmp3", font=("Segoe UI", 20, "bold"),
                     text_color="#1DB954").pack(pady=(20, 30))

        nav_items = [
            ("\U0001F50D  Search", 0),
            ("\U0001F4DA  Library", 1),
            ("\U0001F4CB  Queue", 2),
        ]
        self.nav_btns = []
        self.pages = ["results", "queue"]
        for text, idx in nav_items:
            btn = ctk.CTkButton(side, text=text, anchor="w", height=36,
                                fg_color="transparent", hover_color="#282828",
                                font=("Segoe UI", 13),
                                command=lambda i=idx: self._switch_page(i))
            btn.pack(fill=tk.X, padx=10, pady=2)
            self.nav_btns.append(btn)
        self.nav_btns[0].configure(fg_color="#282828")

        ctk.CTkButton(side, text="Clear Queue", anchor="w", height=36,
                      fg_color="transparent", hover_color="#282828",
                      font=("Segoe UI", 12), command=self._clr_q).pack(side=tk.BOTTOM, fill=tk.X, padx=10, pady=10)

    def _main(self):
        main = ctk.CTkFrame(self.root, corner_radius=0)
        main.grid(row=0, column=1, sticky="nsew")
        main.grid_columnconfigure(0, weight=1)
        main.grid_rowconfigure(1, weight=1)

        top = ctk.CTkFrame(main, fg_color="transparent")
        top.grid(row=0, column=0, sticky="ew", padx=20, pady=(15, 5))
        top.grid_columnconfigure(0, weight=1)

        self.e = ctk.CTkEntry(top, placeholder_text="Search for artists, albums, or tracks...",
                              height=38, font=("Segoe UI", 13))
        self.e.grid(row=0, column=0, sticky="ew", padx=(0, 10))
        self.e.bind("<Return>", lambda e: self._go())
        self.b = ctk.CTkButton(top, text="Search", width=100, height=38,
                                font=("Segoe UI", 13), command=self._go)
        self.b.grid(row=0, column=1)

        content = ctk.CTkFrame(main, fg_color="transparent")
        content.grid(row=1, column=0, sticky="nsew", padx=20, pady=(5, 15))
        content.grid_columnconfigure(0, weight=1)
        content.grid_rowconfigure(0, weight=1)

        self.result_frame = ctk.CTkFrame(content, fg_color="transparent")
        self.result_frame.grid(row=0, column=0, sticky="nsew")
        self.result_frame.grid_columnconfigure(0, weight=1)
        self.result_frame.grid_rowconfigure(0, weight=1)

        self.result_tree = ttk.Treeview(self.result_frame, columns=("a", "b", "c"),
                                        show="tree headings", selectmode="browse",
                                        height=20)
        self.result_tree.heading("#0", text="")
        self.result_tree.heading("a", text="Name")
        self.result_tree.heading("b", text="Type")
        self.result_tree.heading("c", text="Details")
        self.result_tree.column("#0", width=30, stretch=False)
        self.result_tree.column("a", width=350)
        self.result_tree.column("b", width=80)
        self.result_tree.column("c", width=250)

        vsb = ttk.Scrollbar(self.result_frame, orient=tk.VERTICAL, command=self.result_tree.yview)
        self.result_tree.configure(yscrollcommand=vsb.set)
        self.result_tree.grid(row=0, column=0, sticky="nsew")
        vsb.grid(row=0, column=1, sticky="ns")
        self.result_tree.bind("<Double-1>", self._on_dbl)

        self.queue_frame = ctk.CTkFrame(content, fg_color="transparent")
        self.queue_frame.grid_columnconfigure(0, weight=1)
        self.queue_frame.grid_rowconfigure(1, weight=1)

        qtop = ctk.CTkFrame(self.queue_frame, fg_color="transparent")
        qtop.grid(row=0, column=0, sticky="ew", pady=(0, 8))
        self.shuf_btn = ctk.CTkButton(qtop, text="Shuffle", width=80, command=self._toggle_shuffle)
        self.shuf_btn.pack(side=tk.RIGHT, padx=(5, 0))
        self.rep_btn = ctk.CTkButton(qtop, text="Repeat", width=80, command=self._toggle_repeat)
        self.rep_btn.pack(side=tk.RIGHT)

        self.queue_lb = tk.Listbox(self.queue_frame, font=("Segoe UI", 12),
                                   selectmode=tk.SINGLE, activestyle="none",
                                   bg="#1e1e1e", fg="white", highlightthickness=0,
                                   borderwidth=0)
        self.queue_lb.grid(row=1, column=0, sticky="nsew")
        self.queue_lb.bind("<Double-1>", lambda e: self._jump_q())

        qbtns = ctk.CTkFrame(self.queue_frame, fg_color="transparent")
        qbtns.grid(row=2, column=0, sticky="ew", pady=(8, 0))
        ctk.CTkButton(qbtns, text="Play", width=70, command=self._jump_q).pack(side=tk.LEFT, padx=(0, 5))
        ctk.CTkButton(qbtns, text="Remove", width=80, command=self._rm_q).pack(side=tk.LEFT, padx=5)
        ctk.CTkButton(qbtns, text="Clear All", width=80, command=self._clr_q).pack(side=tk.LEFT, padx=5)

        # start with results visible
        self.queue_frame.grid_remove()
        self.current_page = "results"

    def _switch_page(self, idx):
        for i, btn in enumerate(self.nav_btns):
            btn.configure(fg_color="#282828" if i == idx else "transparent")
        if idx == 0:
            self.queue_frame.grid_remove()
            self.result_frame.grid()
            self.current_page = "results"
        elif idx == 2:
            self.result_frame.grid_remove()
            self.queue_frame.grid()
            self.current_page = "queue"

    def _player_bar(self):
        bar = ctk.CTkFrame(self.root, height=90, corner_radius=0)
        bar.grid(row=1, column=1, sticky="nsew")
        bar.grid_columnconfigure(1, weight=1)

        # left: album art + track info
        left = ctk.CTkFrame(bar, fg_color="transparent")
        left.grid(row=0, column=0, sticky="w", padx=(15, 0))

        self.art_lbl = ctk.CTkLabel(left, text="", width=60, height=60)
        self.art_lbl.grid(row=0, column=0, rowspan=2, padx=(0, 10))

        self.st = ctk.CTkLabel(left, text="No track loaded", font=("Segoe UI", 13, "bold"))
        self.st.grid(row=0, column=1, sticky="w")

        self.sub_st = ctk.CTkLabel(left, text="", font=("Segoe UI", 11),
                                    text_color="#888888")
        self.sub_st.grid(row=1, column=1, sticky="w")

        self.dl_btn = ctk.CTkButton(left, text="Download", width=80, height=28,
                                     command=self._download, state=tk.DISABLED)
        self.dl_btn.grid(row=0, column=2, rowspan=2, padx=(15, 0))

        # center: controls
        center = ctk.CTkFrame(bar, fg_color="transparent")
        center.grid(row=0, column=1, sticky="nsew")
        center.grid_rowconfigure(0, weight=1)
        center.grid_rowconfigure(1, weight=0)
        center.grid_columnconfigure(0, weight=1)

        # seek bar row
        seekf = ctk.CTkFrame(center, fg_color="transparent")
        seekf.grid(row=0, column=0, sticky="sew", padx=20, pady=(5, 0))
        seekf.grid_columnconfigure(1, weight=1)

        self.tl_start = ctk.CTkLabel(seekf, text="0:00", font=("Segoe UI", 10),
                                      text_color="#aaaaaa")
        self.tl_start.grid(row=0, column=0, padx=(0, 8))

        self.sk = ctk.CTkSlider(seekf, from_=0, to=1000, height=4,
                                 button_length=12, command=self._seek_drag)
        self.sk.grid(row=0, column=1, sticky="ew")

        self.tl_end = ctk.CTkLabel(seekf, text="0:00", font=("Segoe UI", 10),
                                    text_color="#aaaaaa")
        self.tl_end.grid(row=0, column=2, padx=(8, 0))

        # buttons row
        btnf = ctk.CTkFrame(center, fg_color="transparent")
        btnf.grid(row=1, column=0, sticky="nw", pady=(5, 10))
        center.grid_rowconfigure(0, weight=0)
        center.grid_rowconfigure(1, weight=0)

        self.prv = ctk.CTkButton(btnf, text="\u23ee", width=36, height=32,
                                  font=("Segoe UI", 14), command=self._prev, state=tk.DISABLED)
        self.prv.pack(side=tk.LEFT, padx=2)
        self.pp = ctk.CTkButton(btnf, text="\u25b6", width=36, height=32,
                                 font=("Segoe UI", 14), command=self._toggle, state=tk.DISABLED)
        self.pp.pack(side=tk.LEFT, padx=2)
        self.nxt = ctk.CTkButton(btnf, text="\u23ed", width=36, height=32,
                                  font=("Segoe UI", 14), command=self._next, state=tk.DISABLED)
        self.nxt.pack(side=tk.LEFT, padx=2)

        # right: volume
        right = ctk.CTkFrame(bar, fg_color="transparent")
        right.grid(row=0, column=2, sticky="e", padx=(0, 20))

        ctk.CTkLabel(right, text="\U0001F50A", font=("Segoe UI", 14)).pack(side=tk.LEFT, padx=(0, 5))
        self.vol = ctk.CTkSlider(right, from_=0, to=100, width=100, height=4,
                                  button_length=12, command=lambda v: player.audio_set_volume(int(v)))
        self.vol.set(80)
        self.vol.pack(side=tk.LEFT)

    def _bind(self):
        self.sk.bind("<ButtonPress-1>", lambda e: setattr(self, 'seeking', True))
        self.sk.bind("<ButtonRelease-1>", self._seek_done)
        em = player.event_manager()
        em.event_attach(vlc.EventType.MediaPlayerEndReached, lambda e: self.root.after(0, self._auto_nxt))

    def _toggle_repeat(self):
        self.repeat = (self.repeat + 1) % 3
        labels = {0: "Repeat", 1: "Repeat All", 2: "Repeat One"}
        self.rep_btn.configure(text=labels[self.repeat])

    def _toggle_shuffle(self):
        self.shuffle = not self.shuffle
        if self.shuffle:
            self.shuf_btn.configure(text="Shuffle ON", fg_color="#1DB954")
            if self.queue:
                self._rebuild_shuffle()
        else:
            self.shuf_btn.configure(text="Shuffle", fg_color="#333333")

    def _rebuild_shuffle(self):
        indices = list(range(len(self.queue)))
        if self.qidx in indices:
            indices.remove(self.qidx)
        random.shuffle(indices)
        self.shuffled_indices = [self.qidx] + indices
        self.shuffle_pos = 0

    def _go(self):
        q = self.e.get().strip()
        if not q:
            return
        self.b.configure(state=tk.DISABLED, text="Searching...")
        for i in self.result_tree.get_children():
            self.result_tree.delete(i)
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
                    rows.append(("", aid, "", (x["artistName"], "Artist", ""), ("artist", str(x["artistId"]))))
        except:
            pass
        try:
            r = requests.get(f"{ITUNES}/search", params={"term": q, "entity": "album", "limit": 10}, timeout=10)
            for x in r.json().get("results", []):
                alid = f"al_{x['collectionId']}"
                if alid not in seen:
                    seen.add(alid)
                    p = f"a_{x['artistId']}" if f"a_{x['artistId']}" in seen else ""
                    rows.append((p, alid, "", (x["collectionName"], "Album", x.get("artistName","")), ("album", str(x["collectionId"]))))
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
                    art = x.get("artworkUrl100", "")
                    track_data[tid] = (x["trackName"], x["artistName"], str(x.get("collectionId","")), art)
                    rows.append((p, tid, "", (x["trackName"], "Track", f"{x['artistName']} \u00b7 {m}:{s:02d}"), ("track", tid)))
        except:
            pass
        self.root.after(0, self._show, rows)

    def _show(self, rows):
        self.b.configure(state=tk.NORMAL, text="Search")
        for p, iid, txt, vals, tags in rows:
            try:
                self.result_tree.insert(p, tk.END, iid=iid, text=txt, values=vals, tags=tags)
            except:
                pass

    def _on_dbl(self, event):
        sel = self.result_tree.selection()
        if not sel:
            return
        iid = sel[0]
        tags = self.result_tree.item(iid, "tags")
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
                self._enqueue(info[0], info[1], info[2], info[3] if len(info) > 3 else "")

    def _load_artist(self, aid):
        try:
            r = requests.get(f"{ITUNES}/lookup", params={"id": aid, "entity": "album"}, timeout=10)
            items = r.json().get("results", [])[1:]
        except:
            items = []
        self.root.after(0, self._show_artist, items)

    def _show_artist(self, items):
        sel = self.result_tree.selection()
        if not sel:
            return
        pid = sel[0]
        for c in self.result_tree.get_children(pid):
            self.result_tree.delete(c)
        for x in items:
            alid = f"al_{x['collectionId']}"
            try:
                self.result_tree.insert(pid, tk.END, iid=alid, text="",
                              values=(x["collectionName"], "Album", f"{x.get('trackCount',0)} tracks"),
                              tags=("album", str(x["collectionId"])))
            except:
                pass
        self.result_tree.item(pid, open=True)

    def _load_album(self, alid):
        try:
            r = requests.get(f"{ITUNES}/lookup", params={"id": alid, "entity": "song"}, timeout=10)
            items = r.json().get("results", [])[1:]
        except:
            items = []
        self.root.after(0, self._show_album, items)

    def _show_album(self, items):
        sel = self.result_tree.selection()
        if not sel:
            return
        pid = sel[0]
        for c in self.result_tree.get_children(pid):
            self.result_tree.delete(c)
        for x in items:
            tid = f"t_{x['trackId']}"
            dur = x.get("trackTimeMillis", 0) // 1000
            m, s = divmod(dur, 60)
            art = x.get("artworkUrl100", "")
            track_data[tid] = (x["trackName"], x["artistName"], str(x.get("collectionId","")), art)
            try:
                self.result_tree.insert(pid, tk.END, iid=tid, text="",
                              values=(x["trackName"], "Track", f"{m}:{s:02d}"),
                              tags=("track", tid))
            except:
                pass
        self.result_tree.item(pid, open=True)

    def _enqueue(self, title, artist, album, art_url):
        item = type("Item", (), {"title": title, "artist": artist, "album": album,
                                 "query": f"{artist} {title}", "art_url": art_url})()
        self.queue.append(item)
        self.queue_lb.insert(tk.END, f"{artist} - {title}")
        self.qidx = len(self.queue) - 1
        self.queue_lb.selection_clear(0, tk.END)
        self.queue_lb.selection_set(self.qidx)
        self._update_nav()
        if self.shuffle:
            self._rebuild_shuffle()
        self._play_q()

    def _play_q(self):
        if self.qidx < 0 or self.qidx >= len(self.queue):
            return
        item = self.queue[self.qidx]
        self.now_playing = item
        self.st.configure(text=f"{item.artist} - {item.title}")
        self.sub_st.configure(text=item.album or "")
        if item.art_url:
            photo = fetch_art(item.art_url)
            if photo:
                self.art_lbl.configure(image=photo, text="")
                self.art_lbl.image = photo
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
            self.root.after(0, self._play_vlc, url)
        except Exception as e:
            self.root.after(0, self._err, str(e))

    def _update_nav(self):
        has = self.queue and self.qidx >= 0 and self.qidx < len(self.queue)
        if has:
            self.prv.configure(state=tk.NORMAL if self.qidx > 0 else tk.DISABLED)
            self.nxt.configure(state=tk.NORMAL if self.qidx < len(self.queue) - 1 else tk.DISABLED)
            self.dl_btn.configure(state=tk.NORMAL)
        else:
            self.prv.configure(state=tk.DISABLED)
            self.nxt.configure(state=tk.DISABLED)
            self.dl_btn.configure(state=tk.DISABLED)

    def _play_vlc(self, url):
        try:
            player.stop()
            player.set_media(vlc.Media(url))
            player.play()
            self.paused = False
            self.pp.configure(text="\u23f8", state=tk.NORMAL)
            self._update_nav()
            self.queue_lb.selection_clear(0, tk.END)
            self.queue_lb.selection_set(self.qidx)
            self.queue_lb.see(self.qidx)
        except Exception as e:
            self._err(str(e))

    def _toggle(self):
        if self.paused:
            player.play()
            self.paused = False
            self.pp.configure(text="\u23f8")
        else:
            player.pause()
            self.paused = True
            self.pp.configure(text="\u25b6")

    def _stop(self):
        player.stop()
        self.paused = False
        self.pp.configure(text="\u25b6", state=tk.DISABLED)
        self._update_nav()
        self.sk.set(0)
        self.tl_start.configure(text="0:00")
        self.tl_end.configure(text="0:00")

    def _pick_next(self):
        if self.repeat == 2:
            return self.qidx
        if self.shuffle and self.shuffled_indices:
            self.shuffle_pos += 1
            if self.shuffle_pos < len(self.shuffled_indices):
                return self.shuffled_indices[self.shuffle_pos]
            elif self.repeat == 1:
                self._rebuild_shuffle()
                self.shuffle_pos = 0
                return self.shuffled_indices[0] if self.shuffled_indices else -1
            else:
                return -1
        nxt = self.qidx + 1
        if nxt < len(self.queue):
            return nxt
        elif self.repeat == 1:
            return 0
        else:
            return -1

    def _prev(self):
        if self.qidx > 0:
            self.qidx -= 1
            self._play_q()

    def _next(self):
        nxt = self._pick_next()
        if nxt >= 0:
            self.qidx = nxt
            self._play_q()
        else:
            self._stop()

    def _auto_nxt(self):
        nxt = self._pick_next()
        if nxt >= 0:
            self.qidx = nxt
            self._play_q()
        else:
            self._stop()

    def _jump_q(self):
        sel = self.queue_lb.curselection()
        if sel:
            self.qidx = sel[0]
            self._play_q()

    def _rm_q(self):
        sel = self.queue_lb.curselection()
        if not sel:
            return
        i = sel[0]
        self.queue_lb.delete(i)
        self.queue.pop(i)
        if not self.queue:
            self.qidx = -1
            self._stop()
        elif i <= self.qidx:
            self.qidx = max(0, self.qidx - 1)
            self.queue_lb.selection_set(self.qidx)
        self._update_nav()

    def _clr_q(self):
        self.queue.clear()
        self.queue_lb.delete(0, tk.END)
        self.qidx = -1
        self._stop()
        self._update_nav()
        self.art_lbl.configure(image=ctk.CTkImage(light_image=Image.new("RGB", (1,1), (30,30,30)),
                                                   dark_image=Image.new("RGB", (1,1), (30,30,30)),
                                                   size=(60, 60)), text="")
        self.st.configure(text="No track loaded")
        self.sub_st.configure(text="")

    def _download(self):
        if self.qidx < 0 or self.qidx >= len(self.queue):
            return
        item = self.queue[self.qidx]
        vid = yt_find(item.query)
        if not vid:
            messagebox.showerror("Error", "Could not find YouTube video.")
            return
        default = f"{item.artist} - {item.title}"[:200]
        path = filedialog.asksaveasfilename(defaultextension=".mp3", initialfile=default,
                                              filetypes=[("MP3", "*.mp3"), ("All", "*.*")])
        if not path:
            return
        self.st.configure(text=f"Downloading: {item.title}...")
        threading.Thread(target=self._dl_thread, args=(vid, path, item), daemon=True).start()

    def _dl_thread(self, vid, path, item):
        try:
            r = subprocess.run(YT + [f"https://youtube.com/watch?v={vid}", "-x", "--audio-format", "mp3",
                                     "-o", path, "-q"], capture_output=True, text=True, timeout=120)
            if r.returncode == 0:
                self.root.after(0, lambda: self.st.configure(text=f"Downloaded: {item.artist} - {item.title}"))
                self.root.after(0, lambda: messagebox.showinfo("Done", f"Saved:\n{path}"))
            else:
                self.root.after(0, lambda: self._err(f"Download failed:\n{r.stderr[:200]}"))
        except subprocess.TimeoutExpired:
            self.root.after(0, lambda: self._err("Download timed out."))

    def _seek_drag(self, val):
        if self.seeking:
            length = player.get_length()
            if length > 0:
                pct = float(val) / 1000.0
                cs = int(pct * length / 1000)
                ls = int(length / 1000)
                self.tl_start.configure(text=f"{cs//60}:{cs%60:02d}")
                self.tl_end.configure(text=f"{ls//60}:{ls%60:02d}")

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
                    self.tl_start.configure(text=f"{cs//60}:{cs%60:02d}")
                    self.tl_end.configure(text=f"{ls//60}:{ls%60:02d}")
        except:
            pass
        self.root.after(500, self._tick)

    def _err(self, msg):
        messagebox.showerror("Error", msg)

    def _close(self):
        player.stop()
        self.root.destroy()

    def run(self):
        self.root.mainloop()


if __name__ == "__main__":
    App().run()
