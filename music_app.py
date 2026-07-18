import tkinter as tk
from tkinter import ttk, messagebox, filedialog
import subprocess, sys, threading, json, vlc, requests, time, os, io, random, tempfile, sqlite3
from PIL import Image, ImageTk
import urllib.request
import customtkinter as ctk

ctk.set_appearance_mode("dark")
ctk.set_default_color_theme("green")

YT = [sys.executable, "-m", "yt_dlp", "--remote-components", "ejs:github"]
ITUNES = "https://itunes.apple.com"

vlc_instance = vlc.Instance("--aout=directsound", "--quiet")
player = vlc_instance.media_player_new()
player.audio_set_volume(80)
track_data = {}
art_cache = {}

BG = "#0D1117"
SIDE = "#11161D"
CARD = "#181E27"
ELEV = "#202733"
HOVER = "#262F3D"
GREEN = "#1ED760"
TXT = "#FFFFFF"
TXT2 = "#A6B0BE"
TXT3 = "#727D8A"
DANGER = "#FF4D4F"

DATA_DIR = os.path.join(os.path.expanduser("~"), ".tmp3")
os.makedirs(DATA_DIR, exist_ok=True)
DB_PATH = os.path.join(DATA_DIR, "profiles.db")

LANGUAGE_MAP = {
    "English": ("us", ""), "Hindi": ("in", ""), "Tamil": ("in", "tamil"),
    "Telugu": ("in", "telugu"), "Punjabi": ("in", "punjabi"),
    "Spanish": ("es", ""), "Korean": ("kr", ""), "Japanese": ("jp", ""),
    "French": ("fr", ""), "Arabic": ("sa", ""), "Bengali": ("in", "bengali"),
    "Marathi": ("in", "marathi"), "Gujarati": ("in", "gujarati"),
    "Malayalam": ("in", "malayalam"), "Kannada": ("in", "kannada"),
    "Urdu": ("in", "urdu"), "Bhojpuri": ("in", "bhojpuri"),
    "Russian": ("ru", ""), "Portuguese": ("pt", ""),
}


def init_db():
    conn = sqlite3.connect(DB_PATH)
    conn.execute("""CREATE TABLE IF NOT EXISTS profiles (
        id INTEGER PRIMARY KEY, name TEXT, languages TEXT,
        fav_artists TEXT, created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
    )""")
    conn.execute("""CREATE TABLE IF NOT EXISTS playlists (
        id INTEGER PRIMARY KEY, profile_id INTEGER, name TEXT, source TEXT,
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        FOREIGN KEY(profile_id) REFERENCES profiles(id)
    )""")
    conn.execute("""CREATE TABLE IF NOT EXISTS playlist_tracks (
        id INTEGER PRIMARY KEY, playlist_id INTEGER,
        title TEXT, artist TEXT, album TEXT, art_url TEXT, video_id TEXT,
        position INTEGER,
        FOREIGN KEY(playlist_id) REFERENCES playlists(id)
    )""")
    conn.commit()
    return conn


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
        self.root.geometry("1400x800")
        self.root.minsize(1100, 650)
        self.root.configure(fg_color=BG)

        self.queue = []
        self.qidx = -1
        self.paused = False
        self.seeking = False
        self.repeat = 0
        self.shuffle = False
        self.shuffled_indices = []
        self.shuffle_pos = 0
        self.now_playing = None
        self.db = init_db()
        self.profile_id = None
        self._check_onboarding()

        self._ui()
        self._bind()
        self._tick()
        self.root.protocol("WM_DELETE_WINDOW", self._close)

    def _ui(self):
        self.root.grid_columnconfigure(0, weight=0, minsize=250)
        self.root.grid_columnconfigure(1, weight=1)
        self.root.grid_rowconfigure(0, weight=1)
        self.root.grid_rowconfigure(1, weight=0, minsize=90)

        self._sidebar()
        self._main()
        self._player_bar()

    def _sidebar(self):
        side = ctk.CTkFrame(self.root, width=250, corner_radius=0, fg_color=SIDE)
        side.grid(row=0, column=0, rowspan=2, sticky="nsew")
        side.grid_propagate(False)

        # Logo
        logo = ctk.CTkFrame(side, fg_color="transparent")
        logo.pack(pady=(24, 32), padx=20, fill=tk.X)
        ctk.CTkLabel(logo, text="tmp3", font=("Segoe UI", 22, "bold"),
                     text_color=GREEN).pack(side=tk.LEFT)
        eq = ctk.CTkLabel(logo, text="\U0001F3B6", font=("Segoe UI", 14),
                          text_color=GREEN)
        eq.pack(side=tk.LEFT, padx=(6, 0))

        self.nav_btns = []
        nav_items = [
            ("\U0001F3E0  Home", 0),
            ("\U0001F50D  Search", 1),
            ("\U0001F4FB  Live Streams", 2),
            ("\U0001F3B5  Library", 3),
            ("\u2661  Favorites", 4),
            ("\U0001F4C2  Downloads", 5),
            ("\U0001F552  History", 6),
            ("\u2699  Settings", 7),
        ]
        nf = ctk.CTkFrame(side, fg_color="transparent")
        nf.pack(fill=tk.X, padx=10)
        for text, idx in nav_items:
            btn = ctk.CTkButton(nf, text=text, anchor="w", height=40,
                                fg_color="transparent", hover_color=HOVER,
                                corner_radius=8,
                                font=("Segoe UI", 13),
                                text_color=TXT2,
                                command=lambda i=idx: self._switch_page(i))
            btn.pack(fill=tk.X, pady=1)
            self.nav_btns.append(btn)
        self.nav_btns[0].configure(fg_color=HOVER, text_color=TXT)

        # Playlists section
        sep = ctk.CTkFrame(side, height=1, fg_color=TXT3, corner_radius=0)
        sep.pack(fill=tk.X, padx=20, pady=(24, 16))

        plh = ctk.CTkFrame(side, fg_color="transparent")
        plh.pack(fill=tk.X, padx=20)
        ctk.CTkLabel(plh, text="PLAYLISTS", font=("Segoe UI", 10, "bold"),
                     text_color=TXT3).pack(anchor="w")

        plf = ctk.CTkFrame(side, fg_color="transparent")
        plf.pack(fill=tk.X, padx=10, pady=(8, 0))
        playlists = [
            ("Chill Vibes", "12 songs"),
            ("Road Trip", "8 songs"),
            ("Workout Mix", "15 songs"),
            ("John Mayer Hits", "6 songs"),
        ]
        for pl_name, pl_count in playlists:
            row = ctk.CTkFrame(plf, fg_color="transparent")
            row.pack(fill=tk.X, pady=2)
            ctk.CTkLabel(row, text="\U0001F3B6", font=("Segoe UI", 11),
                         text_color=TXT3, width=24).pack(side=tk.LEFT)
            ctk.CTkLabel(row, text=pl_name, font=("Segoe UI", 12),
                         text_color=TXT2, anchor="w").pack(side=tk.LEFT, fill=tk.X, expand=True, padx=(6, 0))
            ctk.CTkLabel(row, text=pl_count, font=("Segoe UI", 10),
                         text_color=TXT3).pack(side=tk.RIGHT)

        # container for generated user mixes
        self.sidebar_plf = ctk.CTkFrame(side, fg_color="transparent")
        self.sidebar_plf.pack(fill=tk.X, padx=10, pady=(8, 0))

        ctk.CTkButton(side, text="View all playlists \u2192", anchor="w",
                      height=32, fg_color="transparent", hover_color=HOVER,
                      font=("Segoe UI", 11), text_color=TXT3,
                      corner_radius=8).pack(fill=tk.X, padx=20, pady=(8, 0))

    def _main(self):
        main = ctk.CTkFrame(self.root, corner_radius=0, fg_color=BG)
        main.grid(row=0, column=1, sticky="nsew")
        main.grid_columnconfigure(0, weight=1)
        main.grid_rowconfigure(1, weight=1)

        # Top bar
        top = ctk.CTkFrame(main, fg_color="transparent", height=70)
        top.grid(row=0, column=0, sticky="ew", padx=28, pady=(16, 8))
        top.grid_columnconfigure(0, weight=1)
        top.grid_propagate(False)

        # Search bar
        sf = ctk.CTkFrame(top, fg_color=CARD, corner_radius=22, height=42)
        sf.grid(row=0, column=0, sticky="ew", padx=(0, 20))
        sf.grid_columnconfigure(0, weight=0)
        sf.grid_columnconfigure(1, weight=1)
        sf.grid_propagate(False)

        ctk.CTkLabel(sf, text="\U0001F50D", font=("Segoe UI", 14),
                     text_color=TXT3).grid(row=0, column=0, padx=(14, 6))
        self.e = ctk.CTkEntry(sf, placeholder_text="Search artists, songs, albums or live streams...",
                              fg_color="transparent", border_width=0,
                              height=38, font=("Segoe UI", 13), text_color=TXT)
        self.e.grid(row=0, column=1, sticky="ew", padx=(0, 10))
        self.e.bind("<Return>", lambda e: self._show_search())

        # Right side icons
        rside = ctk.CTkFrame(top, fg_color="transparent")
        rside.grid(row=0, column=1, sticky="e")
        for icon, w in [("\U0001F514", 36), ("\U0001F464", 36)]:
            ctk.CTkLabel(rside, text=icon, font=("Segoe UI", 16),
                         text_color=TXT2).pack(side=tk.LEFT, padx=6)

        # Content area
        self.content = ctk.CTkFrame(main, fg_color="transparent", corner_radius=0)
        self.content.grid(row=1, column=0, sticky="nsew", padx=28, pady=(8, 0))
        self.content.grid_columnconfigure(0, weight=1)
        self.content.grid_rowconfigure(0, weight=1)

        self.current_page = "home"
        self._build_home()
        self._build_search()
        self._build_queue()
        self._switch_page(0)

    def _build_home(self):
        self.home_frame = ctk.CTkScrollableFrame(self.content, fg_color="transparent", corner_radius=0)
        self.home_frame.grid(row=0, column=0, sticky="nsew")
        self.home_frame.grid_columnconfigure(0, weight=1)

        # Hero banner
        hero = ctk.CTkFrame(self.home_frame, fg_color="#1a2332", corner_radius=16, height=260)
        hero.grid(row=0, column=0, sticky="ew", pady=(0, 28))
        hero.grid_propagate(False)
        hero.grid_columnconfigure(0, weight=1)

        # Dark overlay with content
        overlay = ctk.CTkFrame(hero, fg_color="transparent")
        overlay.grid(row=0, column=0, sticky="nsew", padx=36, pady=28)
        overlay.grid_columnconfigure(0, weight=1)

        live_badge = ctk.CTkFrame(overlay, fg_color=DANGER, corner_radius=4)
        live_badge.pack(anchor="w")
        ctk.CTkLabel(live_badge, text="  LIVE NOW  ", font=("Segoe UI", 10, "bold"),
                     text_color=TXT).pack()

        ctk.CTkLabel(overlay, text="John Mayer Radio", font=("Segoe UI", 36, "bold"),
                     text_color=TXT, anchor="w").pack(anchor="w", pady=(12, 4))
        ctk.CTkLabel(overlay, text="The best of John Mayer all day long.",
                     font=("Segoe UI", 15), text_color=TXT2, anchor="w").pack(anchor="w", pady=(0, 18))

        bf = ctk.CTkFrame(overlay, fg_color="transparent")
        bf.pack(anchor="w")
        self.h_play = ctk.CTkButton(bf, text="\u25b6  Play Now", width=130, height=38,
                                     fg_color=GREEN, hover_color="#1aa34a",
                                     text_color="#000000", corner_radius=20,
                                     font=("Segoe UI", 13, "bold"),
                                     command=self._hero_play)
        self.h_play.pack(side=tk.LEFT, padx=(0, 10))
        ctk.CTkButton(bf, text="\U0001F500  Shuffle", width=110, height=38,
                      fg_color="transparent", hover_color=HOVER,
                      text_color=TXT, corner_radius=20,
                      border_color=TXT3, border_width=1,
                      font=("Segoe UI", 13),
                      command=self._hero_shuffle).pack(side=tk.LEFT)

        carousel = ctk.CTkFrame(hero, fg_color="transparent", height=20)
        carousel.grid(row=1, column=0, sticky="s")
        for _ in range(3):
            ctk.CTkLabel(carousel, text="\u25cf", font=("Segoe UI", 8),
                         text_color=TXT3).pack(side=tk.LEFT, padx=3)

        # Recently Played
        rp = ctk.CTkFrame(self.home_frame, fg_color="transparent")
        rp.grid(row=2, column=0, sticky="ew", pady=(0, 28))
        rp.grid_columnconfigure(0, weight=1)

        rph = ctk.CTkFrame(rp, fg_color="transparent")
        rph.pack(fill=tk.X)
        ctk.CTkLabel(rph, text="Recently Played", font=("Segoe UI", 20, "bold"),
                     text_color=TXT).pack(side=tk.LEFT)
        ctk.CTkButton(rph, text="View All \u2192", fg_color="transparent",
                      hover_color=HOVER, font=("Segoe UI", 12),
                      text_color=TXT2, corner_radius=8).pack(side=tk.RIGHT)

        self.rec_scroll = ctk.CTkScrollableFrame(rp, fg_color="transparent",
                                                  orientation="horizontal", height=220)
        self.rec_scroll.pack(fill=tk.X, pady=(10, 0))
        self.rec_frame = ctk.CTkFrame(self.rec_scroll, fg_color="transparent")
        self.rec_frame.pack(fill=tk.X)

        # Trending Songs + Live Streams row
        row2 = ctk.CTkFrame(self.home_frame, fg_color="transparent")
        row2.grid(row=3, column=0, sticky="nsew", pady=(0, 28))
        row2.grid_columnconfigure(0, weight=2)
        row2.grid_columnconfigure(1, weight=1, minsize=300)
        row2.grid_rowconfigure(0, weight=1)

        # Trending Songs
        ts = ctk.CTkFrame(row2, fg_color="transparent")
        ts.grid(row=0, column=0, sticky="nsew", padx=(0, 16))
        ts.grid_columnconfigure(0, weight=1)
        ts.grid_rowconfigure(1, weight=1)

        ctk.CTkLabel(ts, text="Trending Songs", font=("Segoe UI", 20, "bold"),
                     text_color=TXT).pack(anchor="w")
        ctk.CTkButton(ts, text="View All \u2192", fg_color="transparent",
                      hover_color=HOVER, font=("Segoe UI", 12),
                      text_color=TXT2, corner_radius=8).pack(anchor="e")

        self.trend_tree = ttk.Treeview(ts,
            columns=("idx", "art", "title", "artist", "dur", "fav", "menu"),
            show="tree", selectmode="browse", height=10)
        self.trend_tree.column("#0", width=0, stretch=False)
        self.trend_tree.column("idx", width=30, anchor="center")
        self.trend_tree.column("art", width=40, anchor="center")
        self.trend_tree.column("title", width=200)
        self.trend_tree.column("artist", width=150)
        self.trend_tree.column("dur", width=60, anchor="center")
        self.trend_tree.column("fav", width=40, anchor="center")
        self.trend_tree.column("menu", width=30, anchor="center")

        style = ttk.Style()
        style.theme_use("clam")
        style.configure("Treeview", background=CARD, foreground=TXT, fieldbackground=CARD,
                        rowheight=48, borderwidth=0, font=("Segoe UI", 12))
        style.configure("Treeview.Heading", background=ELEV, foreground=TXT, borderwidth=0,
                        font=("Segoe UI", 11, "bold"))
        style.map("Treeview", background=[("selected", HOVER)], foreground=[("selected", TXT)])
        style.layout("Treeview", [('Treeview.treearea', {'sticky': 'nswe'})])

        self.trend_tree.pack(fill=tk.BOTH, expand=True, pady=(8, 0))
        self.trend_tree.bind("<Double-1>", self._trend_dbl)

        # Live Streams
        ls = ctk.CTkFrame(row2, fg_color="transparent")
        ls.grid(row=0, column=1, sticky="nsew")

        ctk.CTkLabel(ls, text="Live Streams", font=("Segoe UI", 20, "bold"),
                     text_color=TXT).pack(anchor="w")

        self.live_scroll = ctk.CTkScrollableFrame(ls, fg_color="transparent", height=340)
        self.live_scroll.pack(fill=tk.BOTH, expand=True, pady=(8, 0))

        live_items = [
            ("LoFi Beats", "12.4K", "#1a1a2e"),
            ("Chill Lounge", "8.2K", "#1e2a1e"),
            ("EDM Radio", "5.7K", "#2e1a1a"),
            ("Jazz Lounge", "3.1K", "#1a1a2e"),
        ]
        for name, listeners, color in live_items:
            card = ctk.CTkFrame(self.live_scroll, fg_color=CARD, corner_radius=12, height=72)
            card.pack(fill=tk.X, pady=4)
            card.grid_propagate(False)
            card.grid_columnconfigure(1, weight=1)

            live = ctk.CTkFrame(card, fg_color=DANGER, corner_radius=3, width=36, height=18)
            live.grid(row=0, column=0, rowspan=2, padx=(12, 10), pady=8)
            live.grid_propagate(False)
            ctk.CTkLabel(live, text="LIVE", font=("Segoe UI", 8, "bold"),
                         text_color=TXT).pack(expand=True)

            ctk.CTkLabel(card, text=name, font=("Segoe UI", 13, "bold"),
                         text_color=TXT).grid(row=0, column=1, sticky="s", padx=(0, 8))
            ctk.CTkLabel(card, text=f"{listeners} listeners",
                         font=("Segoe UI", 11), text_color=TXT3).grid(row=1, column=1, sticky="n", padx=(0, 8))

            ctk.CTkButton(card, text="Listen", width=68, height=28,
                          fg_color=GREEN, hover_color="#1aa34a",
                          text_color="#000000", corner_radius=14,
                          font=("Segoe UI", 11, "bold"),
                          command=lambda n=name: self._live_listen(n)).grid(row=0, column=2, rowspan=2, padx=(0, 12))

        # Your Mixes
        mx = ctk.CTkFrame(self.home_frame, fg_color="transparent")
        mx.grid(row=1, column=0, sticky="nsew", pady=(0, 28))
        mx.grid_columnconfigure(0, weight=1)

        hf = ctk.CTkFrame(mx, fg_color="transparent")
        hf.pack(fill=tk.X)
        ctk.CTkLabel(hf, text="Your Mixes", font=("Segoe UI", 20, "bold"),
                     text_color=TXT).pack(side=tk.LEFT)

        self.mix_scroll = ctk.CTkScrollableFrame(mx, fg_color="transparent",
                                                  orientation="horizontal", height=200)
        self.mix_scroll.pack(fill=tk.X, pady=(8, 0))
        self.mix_frame = ctk.CTkFrame(self.mix_scroll, fg_color="transparent")
        self.mix_frame.pack(fill=tk.X)

    def _refresh_home_mixes(self):
        for w in self.mix_frame.winfo_children():
            w.destroy()
        if not hasattr(self, "profile_id") or not self.profile_id:
            return
        c = self.db.execute(
            "SELECT id, name FROM playlists WHERE profile_id=? ORDER BY id", (self.profile_id,))
        pls = c.fetchall()
        if not pls:
            return
        for pl_id, pl_name in pls:
            cc = self.db.execute(
                "SELECT COUNT(*) FROM playlist_tracks WHERE playlist_id=?", (pl_id,))
            count = cc.fetchone()[0]
            card = ctk.CTkFrame(self.mix_frame, fg_color=CARD, corner_radius=12, width=180, height=180)
            card.pack(side=tk.LEFT, padx=6)
            card.pack_propagate(False)
            ctk.CTkLabel(card, text="\U0001F3B6", font=("Segoe UI", 28)).pack(pady=(16, 4))
            ctk.CTkLabel(card, text=pl_name, font=("Segoe UI", 13, "bold"),
                         text_color=TXT).pack()
            ctk.CTkLabel(card, text=f"{count} tracks", font=("Segoe UI", 10),
                         text_color=TXT3).pack()
            ctk.CTkButton(card, text="\u25b6  Open", width=80, height=28,
                          fg_color=GREEN, hover_color="#1aa34a",
                          text_color="#000000", corner_radius=14,
                          font=("Segoe UI", 11, "bold"),
                          command=lambda pid=pl_id: self._open_playlist(pid)).pack(pady=(8, 0))

    def _build_search(self):
        self.search_frame = ctk.CTkFrame(self.content, fg_color="transparent", corner_radius=0)
        self.search_frame.grid(row=0, column=0, sticky="nsew")
        self.search_frame.grid_columnconfigure(0, weight=1)
        self.search_frame.grid_rowconfigure(1, weight=1)
        self.search_frame.grid_remove()

        # Filter buttons
        ff = ctk.CTkFrame(self.search_frame, fg_color="transparent")
        ff.grid(row=0, column=0, sticky="ew", pady=(0, 10))

        self._active_filter = "All"
        self._filter_btns = {}
        self._last_query = ""
        for i, label in enumerate(["All", "Songs", "Artists", "Albums"]):
            btn = ctk.CTkButton(ff, text=label, width=80, height=30,
                                font=("Segoe UI", 12),
                                fg_color=GREEN if label == "All" else CARD,
                                hover_color="#1aa34a" if label == "All" else HOVER,
                                text_color="#000000" if label == "All" else TXT2,
                                corner_radius=16,
                                command=lambda l=label: self._set_filter(l))
            btn.grid(row=0, column=i, padx=(0, 8))
            self._filter_btns[label] = btn

        # Results tree
        rf = ctk.CTkFrame(self.search_frame, fg_color="transparent")
        rf.grid(row=1, column=0, sticky="nsew")
        rf.grid_columnconfigure(0, weight=1)
        rf.grid_rowconfigure(0, weight=1)

        self.result_tree = ttk.Treeview(rf, columns=("a", "b", "c"),
                                        show="tree headings", selectmode="browse", height=20)
        self.result_tree.heading("#0", text="")
        self.result_tree.heading("a", text="Name")
        self.result_tree.heading("b", text="Type")
        self.result_tree.heading("c", text="Details")
        self.result_tree.column("#0", width=30, stretch=False)
        self.result_tree.column("a", width=400)
        self.result_tree.column("b", width=100)
        self.result_tree.column("c", width=300)
        self.result_tree.configure(style="Treeview")
        self.result_tree.grid(row=0, column=0, sticky="nsew")
        vsb = ttk.Scrollbar(rf, orient=tk.VERTICAL, command=self.result_tree.yview)
        self.result_tree.configure(yscrollcommand=vsb.set)
        vsb.grid(row=0, column=1, sticky="ns")
        self.result_tree.bind("<Double-1>", self._on_dbl)

    def _build_queue(self):
        self.queue_frame = ctk.CTkFrame(self.content, fg_color="transparent", corner_radius=0)
        self.queue_frame.grid(row=0, column=0, sticky="nsew")
        self.queue_frame.grid_columnconfigure(0, weight=1)
        self.queue_frame.grid_rowconfigure(1, weight=1)
        self.queue_frame.grid_remove()

        qtop = ctk.CTkFrame(self.queue_frame, fg_color="transparent")
        qtop.grid(row=0, column=0, sticky="ew", pady=(0, 12))
        ctk.CTkLabel(qtop, text="Queue", font=("Segoe UI", 22, "bold"),
                     text_color=TXT).pack(side=tk.LEFT)
        self.shuf_btn = ctk.CTkButton(qtop, text="Shuffle", width=80, command=self._toggle_shuffle,
                                       fg_color=CARD, hover_color=HOVER, corner_radius=14,
                                       font=("Segoe UI", 12))
        self.shuf_btn.pack(side=tk.RIGHT, padx=(8, 0))
        self.rep_btn = ctk.CTkButton(qtop, text="Repeat", width=80, command=self._toggle_repeat,
                                      fg_color=CARD, hover_color=HOVER, corner_radius=14,
                                      font=("Segoe UI", 12))
        self.rep_btn.pack(side=tk.RIGHT)

        qf = ctk.CTkFrame(self.queue_frame, fg_color=CARD, corner_radius=12)
        qf.grid(row=1, column=0, sticky="nsew")
        qf.grid_columnconfigure(0, weight=1)
        qf.grid_rowconfigure(0, weight=1)

        self.queue_lb = tk.Listbox(qf, font=("Segoe UI", 13),
                                   selectmode=tk.SINGLE, activestyle="none",
                                   bg=CARD, fg=TXT, highlightthickness=0,
                                   borderwidth=0)
        self.queue_lb.grid(row=0, column=0, sticky="nsew", padx=8, pady=8)
        self.queue_lb.bind("<Double-1>", lambda e: self._jump_q())

        qbtns = ctk.CTkFrame(self.queue_frame, fg_color="transparent")
        qbtns.grid(row=2, column=0, sticky="ew", pady=(12, 0))
        ctk.CTkButton(qbtns, text="Play", width=70, command=self._jump_q,
                      fg_color=GREEN, hover_color="#1aa34a", text_color="#000000",
                      corner_radius=14, font=("Segoe UI", 12)).pack(side=tk.LEFT, padx=(0, 8))
        ctk.CTkButton(qbtns, text="Remove", width=80, command=self._rm_q,
                      fg_color=CARD, hover_color=HOVER, corner_radius=14,
                      font=("Segoe UI", 12)).pack(side=tk.LEFT, padx=4)
        ctk.CTkButton(qbtns, text="Clear All", width=80, command=self._clr_q,
                      fg_color=CARD, hover_color=HOVER, corner_radius=14,
                      font=("Segoe UI", 12)).pack(side=tk.LEFT, padx=4)

    def _player_bar(self):
        bar = ctk.CTkFrame(self.root, height=90, corner_radius=0, fg_color="#131a22")
        bar.grid(row=1, column=1, sticky="nsew")
        bar.grid_columnconfigure(1, weight=1)

        # Left: album art + info
        left = ctk.CTkFrame(bar, fg_color="transparent")
        left.grid(row=0, column=0, sticky="w", padx=(16, 0))

        self.art_lbl = ctk.CTkLabel(left, text="", width=56, height=56, corner_radius=8)
        self.art_lbl.grid(row=0, column=0, rowspan=2, padx=(0, 12))

        self.st = ctk.CTkLabel(left, text="No track loaded", font=("Segoe UI", 13, "bold"),
                                text_color=TXT)
        self.st.grid(row=0, column=1, sticky="w")
        self.sub_st = ctk.CTkLabel(left, text="", font=("Segoe UI", 11), text_color=TXT3)
        self.sub_st.grid(row=1, column=1, sticky="w")

        ctk.CTkLabel(left, text="\u2661", font=("Segoe UI", 16), text_color=TXT3).grid(row=0, column=2, rowspan=2, padx=(14, 0))

        dlf = ctk.CTkFrame(left, fg_color="transparent")
        dlf.grid(row=0, column=3, rowspan=2, padx=(12, 0))
        self.dl_q = ctk.CTkOptionMenu(dlf, values=["Original", "MP3 V0"],
                                       width=90, height=26, font=("Segoe UI", 10),
                                       fg_color=CARD, button_color=ELEV,
                                       button_hover_color=HOVER, dropdown_fg_color=CARD,
                                       dropdown_hover_color=HOVER,
                                       text_color=TXT)
        self.dl_q.pack(side=tk.LEFT, padx=(0, 4))
        self.dl_q.set("Original")
        self.dl_btn = ctk.CTkButton(dlf, text="Download", width=68, height=26,
                                     command=self._download, state=tk.DISABLED,
                                     fg_color=CARD, hover_color=HOVER, corner_radius=14,
                                     font=("Segoe UI", 10), text_color=TXT)
        self.dl_btn.pack(side=tk.LEFT)

        # Center: controls
        center = ctk.CTkFrame(bar, fg_color="transparent")
        center.grid(row=0, column=1, sticky="nsew")
        center.grid_rowconfigure(0, weight=1)
        center.grid_rowconfigure(1, weight=0)
        center.grid_columnconfigure(0, weight=1)

        # Seek bar
        seekf = ctk.CTkFrame(center, fg_color="transparent")
        seekf.grid(row=0, column=0, sticky="sew", padx=40, pady=(6, 0))
        seekf.grid_columnconfigure(1, weight=1)

        self.tl_start = ctk.CTkLabel(seekf, text="0:00", font=("Segoe UI", 10), text_color=TXT3)
        self.tl_start.grid(row=0, column=0, padx=(0, 8))

        self.sk = ctk.CTkSlider(seekf, from_=0, to=1000, height=4,
                                 button_length=12, fg_color=ELEV,
                                 progress_color=GREEN, button_color=GREEN,
                                 command=self._seek_drag)
        self.sk.grid(row=0, column=1, sticky="ew")

        self.tl_end = ctk.CTkLabel(seekf, text="0:00", font=("Segoe UI", 10), text_color=TXT3)
        self.tl_end.grid(row=0, column=2, padx=(8, 0))

        # Buttons
        btnf = ctk.CTkFrame(center, fg_color="transparent")
        btnf.grid(row=1, column=0, sticky="n", pady=(4, 10))

        ctk.CTkButton(btnf, text="\U0001F500", width=30, height=30,
                      fg_color="transparent", hover_color=HOVER,
                      font=("Segoe UI", 11), text_color=TXT2, corner_radius=15).pack(side=tk.LEFT, padx=4)
        self.prv = ctk.CTkButton(btnf, text="\u23ee", width=30, height=30,
                                  fg_color="transparent", hover_color=HOVER,
                                  font=("Segoe UI", 14), state=tk.DISABLED,
                                  text_color=TXT, corner_radius=15,
                                  command=self._prev)
        self.prv.pack(side=tk.LEFT, padx=4)
        self.pp = ctk.CTkButton(btnf, text="\u25b6", width=38, height=38,
                                 fg_color=TXT, hover_color=TXT2,
                                 font=("Segoe UI", 16), state=tk.DISABLED,
                                 text_color="#000000", corner_radius=19,
                                 command=self._toggle)
        self.pp.pack(side=tk.LEFT, padx=6)
        self.nxt = ctk.CTkButton(btnf, text="\u23ed", width=30, height=30,
                                  fg_color="transparent", hover_color=HOVER,
                                  font=("Segoe UI", 14), state=tk.DISABLED,
                                  text_color=TXT, corner_radius=15,
                                  command=self._next)
        self.nxt.pack(side=tk.LEFT, padx=4)
        ctk.CTkButton(btnf, text="\U0001F501", width=30, height=30,
                      fg_color="transparent", hover_color=HOVER,
                      font=("Segoe UI", 11), text_color=TXT2, corner_radius=15).pack(side=tk.LEFT, padx=4)

        # Right: volume
        right = ctk.CTkFrame(bar, fg_color="transparent")
        right.grid(row=0, column=2, sticky="e", padx=(0, 20))

        ctk.CTkButton(right, text="\U0001F4C4", width=30, height=30,
                      fg_color="transparent", hover_color=HOVER,
                      font=("Segoe UI", 12), text_color=TXT2, corner_radius=15,
                      command=self._show_queue_page).pack(side=tk.LEFT, padx=2)
        ctk.CTkLabel(right, text="\U0001F509", font=("Segoe UI", 14), text_color=TXT2).pack(side=tk.LEFT, padx=(4, 4))
        self.vol = ctk.CTkSlider(right, from_=0, to=100, width=80, height=4,
                                  fg_color=ELEV, progress_color=GREEN,
                                  button_color=GREEN, button_length=12,
                                  command=lambda v: player.audio_set_volume(int(v)))
        self.vol.set(80)
        self.vol.pack(side=tk.LEFT)

    def _switch_page(self, idx):
        for i, btn in enumerate(self.nav_btns):
            active = i == idx
            btn.configure(fg_color=HOVER if active else "transparent",
                          text_color=TXT if active else TXT2)

        for name in ["home_frame", "search_frame", "queue_frame"]:
            f = getattr(self, name, None)
            if f:
                f.grid_remove()

        if idx == 0:
            self.home_frame.grid()
            self.current_page = "home"
        elif idx == 1:
            self.search_frame.grid()
            self.current_page = "search"
        elif idx == 2:
            # Live Streams — reuse home frame but could scroll to streams
            self.home_frame.grid()
            self.current_page = "home"
        elif idx == 3:
            # Library — reuse search
            self.search_frame.grid()
            self.current_page = "search"
        elif idx == 4:
            # Favorites — home for now
            self.home_frame.grid()
            self.current_page = "home"
        elif idx == 5:
            self.home_frame.grid()
            self.current_page = "home"
        elif idx == 6:
            self.home_frame.grid()
            self.current_page = "home"
        elif idx == 7:
            self.home_frame.grid()
            self.current_page = "home"

    def _show_search(self):
        q = self.e.get().strip()
        if not q:
            return
        self._last_query = q
        self._active_filter = "All"
        for k, btn in self._filter_btns.items():
            btn.configure(fg_color=GREEN if k == "All" else CARD,
                          text_color="#000000" if k == "All" else TXT2)
        for i in self.result_tree.get_children():
            self.result_tree.delete(i)
        track_data.clear()
        threading.Thread(target=self._search, args=(q,), daemon=True).start()
        # Switch to search view
        for name in ["home_frame", "search_frame", "queue_frame"]:
            f = getattr(self, name, None)
            if f:
                f.grid_remove()
        self.search_frame.grid()
        self.current_page = "search"
        for i, btn in enumerate(self.nav_btns):
            btn.configure(fg_color=HOVER if i == 1 else "transparent",
                          text_color=TXT if i == 1 else TXT2)

    def _search(self, q):
        rows = []
        seen = set()
        try:
            r = requests.get(f"{ITUNES}/search", params={"term": q, "entity": "musicArtist", "limit": 5}, timeout=10)
            for x in r.json().get("results", []):
                aid = f"a_{x['artistId']}"
                if aid not in seen:
                    seen.add(aid)
                    aname = x["artistName"]
                    aid_raw = str(x["artistId"])
                    rows.append(("", aid, "", (aname, "Artist", ""), ("artist", aid_raw)))
                    try:
                        rs = requests.get(f"{ITUNES}/search", params={"term": aname, "entity": "song", "limit": 20}, timeout=10)
                        for s in rs.json().get("results", []):
                            if str(s.get("artistId")) == aid_raw:
                                tid = f"t_{s['trackId']}"
                                if tid not in seen:
                                    seen.add(tid)
                                    dur = s.get("trackTimeMillis", 0) // 1000
                                    m, sec = divmod(dur, 60)
                                    art = s.get("artworkUrl100", "")
                                    track_data[tid] = (s["trackName"], s["artistName"], str(s.get("collectionId","")), art)
                                    rows.append((aid, tid, "", (s["trackName"], "Track", f"{m}:{sec:02d}"), ("track", tid)))
                    except:
                        pass
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
        for p, iid, txt, vals, tags in rows:
            try:
                self.result_tree.insert(p, tk.END, iid=iid, text=txt, values=vals, tags=tags)
            except:
                pass
        for iid in self.result_tree.get_children():
            tags = self.result_tree.item(iid, "tags")
            if tags and tags[0] in ("artist", "album", "label"):
                self.result_tree.item(iid, open=True)

    def _set_filter(self, label):
        self._active_filter = label
        for k, btn in self._filter_btns.items():
            btn.configure(fg_color=GREEN if k == label else CARD,
                          text_color="#000000" if k == label else TXT2)
        q = self._last_query
        if not q:
            return
        for i in self.result_tree.get_children():
            self.result_tree.delete(i)
        threading.Thread(target=self._filtered_search, args=(q, label), daemon=True).start()

    def _filtered_search(self, q, filt):
        rows = []
        seen = set()
        track_data.clear()
        entity_map = {"Songs": "song", "Artists": "musicArtist", "Albums": "album"}
        entity = entity_map.get(filt, "song")
        limit_map = {"Songs": 200, "Artists": 10, "Albums": 200}
        lim = limit_map.get(filt, 200)
        try:
            r = requests.get(f"{ITUNES}/search", params={"term": q, "entity": entity, "limit": lim}, timeout=15)
            if entity == "musicArtist":
                for x in r.json().get("results", []):
                    aid = f"a_{x['artistId']}"
                    if aid not in seen:
                        seen.add(aid)
                        rows.append(("", aid, "", (x["artistName"], "Artist", ""), ("artist", str(x["artistId"]))))
            elif entity == "song":
                originals, collabs, remixes = [], [], []
                ql = q.lower()
                for x in r.json().get("results", []):
                    tid = f"t_{x['trackId']}"
                    if tid in seen:
                        continue
                    seen.add(tid)
                    dur = x.get("trackTimeMillis", 0) // 1000
                    m, s_div = divmod(dur, 60)
                    art = x.get("artworkUrl100", "")
                    track_data[tid] = (x["trackName"], x["artistName"], str(x.get("collectionId","")), art)
                    entry = (tid, x["trackName"], x["artistName"], f"{m}:{s_div:02d}")
                    title_lower = x["trackName"].lower()
                    if "remix" in title_lower:
                        remixes.append(entry)
                    elif x["artistName"].lower() != ql:
                        collabs.append(entry)
                    else:
                        originals.append(entry)
                if originals:
                    rows.append(("", "_sec_originals", "", ("Songs", "", ""), ("label", "")))
                    for tid, tn, an, dur in originals:
                        rows.append(("_sec_originals", tid, "", (tn, an, dur), ("track", tid)))
                if collabs:
                    rows.append(("", "_sec_collabs", "", ("Collaborations", "", ""), ("label", "")))
                    for tid, tn, an, dur in collabs:
                        rows.append(("_sec_collabs", tid, "", (tn, an, dur), ("track", tid)))
                if remixes:
                    rows.append(("", "_sec_remixes", "", ("Remixes", "", ""), ("label", "")))
                    for tid, tn, an, dur in remixes:
                        rows.append(("_sec_remixes", tid, "", (tn, an, dur), ("track", tid)))
            else:
                albums_list, appearances = [], []
                ql = q.lower()
                for x in r.json().get("results", []):
                    alid = f"al_{x['collectionId']}"
                    if alid in seen:
                        continue
                    seen.add(alid)
                    an = x.get("artistName", "")
                    cid = str(x["collectionId"])
                    entry = (alid, x["collectionName"], an, f"{x.get('trackCount',0)} tracks", cid)
                    if an.lower() == ql:
                        albums_list.append(entry)
                    else:
                        appearances.append(entry)
                if albums_list:
                    rows.append(("", "_sec_albums", "", ("Albums", "", ""), ("label", "")))
                    for alid, cn, an, tc, cid in albums_list:
                        rows.append(("_sec_albums", alid, "", (cn, an, tc), ("album", cid)))
                if appearances:
                    rows.append(("", "_sec_appearances", "", ("Appearances", "", ""), ("label", "")))
                    for alid, cn, an, tc, cid in appearances:
                        rows.append(("_sec_appearances", alid, "", (cn, an, tc), ("album", cid)))
        except:
            pass
        self.root.after(0, self._show, rows)

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

    def _trend_dbl(self, event):
        sel = self.trend_tree.selection()
        if not sel:
            return
        iid = sel[0]
        vals = self.trend_tree.item(iid, "values")
        if vals and len(vals) >= 4:
            title = vals[2] if len(vals) > 2 else ""
            artist = vals[3] if len(vals) > 3 else ""
            if title and artist:
                self._enqueue(title, artist, "", "")

    def _load_artist(self, aid):
        try:
            r = requests.get(f"{ITUNES}/lookup", params={"id": aid, "entity": "album"}, timeout=10)
            albums = r.json().get("results", [])[1:]
        except:
            albums = []
        self.root.after(0, self._show_artist, albums)

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

    def yt_search(self, query, max_results=6):
        r = subprocess.run(YT + [f"ytsearch{max_results}:{query}", "--flat-playlist", "--dump-json"],
                           capture_output=True, text=True, timeout=30)
        if r.returncode != 0:
            return []
        out = []
        for line in r.stdout.strip().splitlines():
            if line.strip():
                try:
                    d = json.loads(line)
                    out.append({"id": d["id"], "title": d.get("title", "?"),
                                "channel": d.get("channel", d.get("uploader", "?")),
                                "duration": d.get("duration", 0)})
                except:
                    continue
        return out

    def _pick_source(self, item, results, callback):
        if not results:
            self.root.after(0, lambda: self._err("No YouTube results found."))
            return
        win = ctk.CTkToplevel(self.root)
        win.title("Select Source")
        win.geometry("600x400")
        win.transient(self.root)
        win.grab_set()
        ctk.CTkLabel(win, text=f"Select YouTube source for:", font=("Segoe UI", 12)).pack(pady=(10, 2))
        ctk.CTkLabel(win, text=f"{item.artist} - {item.title}", font=("Segoe UI", 14, "bold")).pack(pady=(0, 10))
        frame = ctk.CTkScrollableFrame(win, height=250)
        frame.pack(fill=tk.BOTH, expand=True, padx=10, pady=(0, 10))
        buttons = []
        for i, res in enumerate(results):
            dur = res.get("duration", 0)
            m, s = divmod(dur, 60)
            dur_str = f"{m}:{s:02d}" if dur else "?:??"
            card = ctk.CTkFrame(frame)
            card.pack(fill=tk.X, pady=3)
            info = f"{res['title']}  |  {res['channel']}  |  {dur_str}"
            btn = ctk.CTkButton(card, text=info, anchor="w", height=32,
                                fg_color=CARD, hover_color=GREEN,
                                font=("Segoe UI", 11))
            btn.pack(fill=tk.X)
            buttons.append((btn, res["id"]))
        def select(idx):
            item.video_id = buttons[idx][1]
            win.destroy()
            callback(item)
        for i, (btn, _) in enumerate(buttons):
            btn.configure(command=lambda i=i: select(i))
        ctk.CTkButton(win, text="Cancel", command=win.destroy).pack(pady=(0, 10))

    def _enqueue(self, title, artist, album, art_url):
        item = type("Item", (), {"title": title, "artist": artist, "album": album,
                                 "query": f"{artist} {title}", "art_url": art_url,
                                 "video_id": None})()
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
            if not item.video_id:
                results = self.yt_search(item.query)
                self.root.after(0, lambda: self._pick_source(item, results, self._continue_play))
                return
            self._continue_play(item)
        except Exception as e:
            self.root.after(0, self._err, str(e))

    def _continue_play(self, item):
        vid = item.video_id or yt_find(item.query)
        if not vid:
            self.root.after(0, self._err, f"No YouTube match for {item.title}")
            return
        url = yt_stream(vid)
        if not url:
            self.root.after(0, self._err, f"Stream error for {item.title}")
            return
        self.root.after(0, self._play_vlc, url)

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
            player.audio_set_volume(int(self.vol.get()))
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
                                                   size=(56, 56)), text="")
        self.st.configure(text="No track loaded")
        self.sub_st.configure(text="")

    def _hero_play(self):
        if self.queue:
            self.qidx = 0
            self._play_q()

    def _hero_shuffle(self):
        if self.queue:
            self.shuffle = True
            self._rebuild_shuffle()
            self._next()

    def _show_queue_page(self):
        for name in ["home_frame", "search_frame", "queue_frame"]:
            f = getattr(self, name, None)
            if f:
                f.grid_remove()
        self.queue_frame.grid()
        self.current_page = "queue"
        # reset nav highlights
        for btn in self.nav_btns:
            btn.configure(fg_color="transparent", text_color=TXT2)

    def _live_listen(self, name):
        self._enqueue(f"{name} Stream", "tmp3", "", "")

    def _download(self):
        if self.qidx < 0 or self.qidx >= len(self.queue):
            return
        item = self.queue[self.qidx]
        self.st.configure(text=f"Downloading: {item.title}...")
        threading.Thread(target=self._dl_prep, args=(item,), daemon=True).start()

    def _dl_prep(self, item):
        convert = self.dl_q.get() == "MP3 V0"
        vid = yt_find(item.query)
        if not vid:
            self.root.after(0, lambda: self._err("Could not find YouTube video."))
            return
        base = os.path.join(tempfile.gettempdir(), f"tmp3_{vid}")
        tmp = base + ".%(ext)s"
        cmd = YT + [f"https://youtube.com/watch?v={vid}", "-f", "bestaudio", "-o", tmp, "-q"]
        if convert:
            cmd += ["-x", "--audio-format", "mp3", "--audio-quality", "0"]
        r = subprocess.run(cmd, capture_output=True, text=True, timeout=120)
        if r.returncode != 0:
            self.root.after(0, lambda: self._err(f"Download failed:\n{r.stderr[:200]}"))
            return
        found = None
        for f in os.listdir(tempfile.gettempdir()):
            if f.startswith(f"tmp3_{vid}") and os.path.isfile(os.path.join(tempfile.gettempdir(), f)):
                found = os.path.join(tempfile.gettempdir(), f)
                break
        if not found:
            self.root.after(0, lambda: self._err("File not found after download."))
            return
        ext = os.path.splitext(found)[1]
        default = f"{item.artist} - {item.title}{ext}"[:200]
        self.root.after(0, lambda: self._dl_save(found, default, item))

    def _sanitize(self, name):
        for ch in ['/', '\\', ':', '*', '?', '"', '<', '>', '|', '\n', '\r']:
            name = name.replace(ch, '_')
        return name.strip('. ') or "track"

    def _dl_save(self, src, default_name, item):
        default_name = self._sanitize(default_name)
        initial_dir = os.path.join(os.path.expanduser("~"), "Downloads")
        if not os.path.exists(initial_dir):
            initial_dir = os.path.expanduser("~")
        path = filedialog.asksaveasfilename(parent=self.root, initialdir=initial_dir,
                                              initialfile=default_name,
                                              defaultextension="",
                                              filetypes=[("All files", "*.*")])
        if not path:
            try:
                if os.path.exists(src):
                    os.remove(src)
            except:
                pass
            return
        self.st.configure(text=f"Saving: {item.title}...")
        try:
            if not os.path.exists(src):
                self._err("Temp file missing before copy. Try downloading again.")
                return
            import shutil
            shutil.copy2(src, path)
            os.remove(src)
            self.st.configure(text=f"Downloaded: {item.artist} - {item.title}")
            messagebox.showinfo("Done", f"Saved to:\n{path}")
        except Exception as e:
            self._err(f"Save failed: {e}")

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
            self.shuf_btn.configure(text="Shuffle ON", fg_color=GREEN)
            if self.queue:
                self._rebuild_shuffle()
        else:
            self.shuf_btn.configure(text="Shuffle", fg_color=CARD)

    def _rebuild_shuffle(self):
        indices = list(range(len(self.queue)))
        if self.qidx in indices:
            indices.remove(self.qidx)
        random.shuffle(indices)
        self.shuffled_indices = [self.qidx] + indices
        self.shuffle_pos = 0

    def _err(self, msg):
        messagebox.showerror("Error", msg)

    def _close(self):
        player.stop()
        self.root.destroy()

    def _check_onboarding(self):
        c = self.db.execute("SELECT id, languages, fav_artists FROM profiles ORDER BY id LIMIT 1")
        row = c.fetchone()
        if row and row[2]:
            self.profile_id = row[0]
            self.profile_languages = json.loads(row[1]) if row[1] else []
            self.profile_artists = json.loads(row[2]) if row[2] else []
            self.root.after(100, self._refresh_home_mixes)
        else:
            self.root.after(500, self._onboarding_wizard)

    def _onboarding_wizard(self):
        win = ctk.CTkToplevel(self.root)
        win.title("Welcome to tmp3")
        win.geometry("650x550")
        win.transient(self.root)
        win.grab_set()
        win.resizable(False, False)

        container = ctk.CTkFrame(win, fg_color=BG, corner_radius=0)
        container.pack(fill=tk.BOTH, expand=True, padx=0, pady=0)
        container.grid_columnconfigure(0, weight=1)
        container.grid_rowconfigure(0, weight=1)

        step_frame = ctk.CTkFrame(container, fg_color="transparent")
        step_frame.grid(row=0, column=0, sticky="nsew", padx=40, pady=30)
        step_frame.grid_columnconfigure(0, weight=1)
        step_frame.grid_rowconfigure(0, weight=1)

        self._onboard_step1(step_frame, win, container)

    def _onboard_step1(self, parent, win, container):
        for w in parent.winfo_children():
            w.destroy()

        ctk.CTkLabel(parent, text="What languages do you listen to?",
                     font=("Segoe UI", 22, "bold"), text_color=TXT).pack(anchor="w", pady=(0, 6))
        ctk.CTkLabel(parent, text="Pick all that apply — we'll curate playlists from these.",
                     font=("Segoe UI", 13), text_color=TXT2).pack(anchor="w", pady=(0, 20))

        sf = ctk.CTkScrollableFrame(parent, fg_color="transparent", height=240)
        sf.pack(fill=tk.BOTH, expand=True)

        vars = {}
        for lang in sorted(LANGUAGE_MAP.keys()):
            v = tk.BooleanVar(value=lang in ("English",))
            vars[lang] = v
            cb = ctk.CTkCheckBox(sf, text=lang, variable=v, font=("Segoe UI", 14),
                                  text_color=TXT, fg_color=GREEN, hover_color=GREEN,
                                  corner_radius=4, checkbox_width=22, checkbox_height=22)
            cb.pack(anchor="w", pady=4)

        def next():
            selected = [l for l, v in vars.items() if v.get()]
            if not selected:
                messagebox.showwarning("Select", "Pick at least one language.", parent=win)
                return
            self._onboard_step2(parent, win, container, selected)

        ctk.CTkButton(parent, text="Next  \u2192", command=next,
                      fg_color=GREEN, hover_color="#1aa34a", text_color="#000000",
                      font=("Segoe UI", 14, "bold"), corner_radius=14, height=40).pack(pady=(16, 0))

    def _make_circular(self, url, size=(56, 56)):
        try:
            data = urllib.request.urlopen(url, timeout=4).read()
            img = Image.open(io.BytesIO(data)).resize(size, Image.LANCZOS)
            mask = Image.new("L", size, 0)
            from PIL import ImageDraw
            draw = ImageDraw.Draw(mask)
            draw.ellipse((0, 0) + size, fill=255)
            img.putalpha(mask)
            return ctk.CTkImage(light_image=img, dark_image=img, size=size)
        except:
            return None

    def _onboard_step2(self, parent, win, container, languages):
        for w in parent.winfo_children():
            w.destroy()

        parent.grid_columnconfigure(0, weight=1)
        parent.grid_rowconfigure(0, weight=1)
        parent.grid_rowconfigure(1, weight=0)

        main = ctk.CTkFrame(parent, fg_color="transparent")
        main.grid(row=0, column=0, sticky="nsew")

        ctk.CTkLabel(main, text="Who are your favorite artists?",
                     font=("Segoe UI", 22, "bold"), text_color=TXT).pack(anchor="w", pady=(0, 4))
        ctk.CTkLabel(main, text="Search and tap an artist to add them. Pick 3+ for best mixes.",
                     font=("Segoe UI", 13), text_color=TXT2).pack(anchor="w", pady=(0, 6))

        sel_f = ctk.CTkFrame(main, fg_color="transparent", height=60)
        sel_f.pack(fill=tk.X, pady=(0, 4))
        sel_f.pack_propagate(False)

        sf = ctk.CTkFrame(main, fg_color="transparent")
        sf.pack(fill=tk.X, pady=(0, 6))
        sf.grid_columnconfigure(0, weight=1)
        e = ctk.CTkEntry(sf, placeholder_text="Search for an artist...",
                          fg_color=CARD, border_width=0, height=38, font=("Segoe UI", 13))
        e.grid(row=0, column=0, sticky="ew", padx=(0, 6))

        self._onb_results = ctk.CTkScrollableFrame(main, fg_color="transparent", height=160)
        self._onb_results.pack(fill=tk.X, pady=(0, 4))

        self._onb_suggest = ctk.CTkScrollableFrame(main, fg_color="transparent", height=80)
        self._onb_suggest.pack(fill=tk.X)

        self._onb_added = added = []
        self._onb_added_data = added_data = {}
        self._onb_update_sel = lambda: None  # placeholder used by _onb_show_related

        def update_sel():
            for w in sel_f.winfo_children():
                w.destroy()
            for a in added:
                data = added_data.get(a, {})
                url = data.get("img_url", "")
                cf = ctk.CTkFrame(sel_f, fg_color="transparent")
                cf.pack(side=tk.LEFT, padx=3)
                img = None
                if url:
                    img = self._make_circular(url.replace("100x100", "60x60"), (44, 44))
                lbl = ctk.CTkLabel(cf, text="", image=img, width=44, height=44,
                                   corner_radius=22) if img else ctk.CTkLabel(cf, text="\U0001F3B5", font=("Segoe UI", 20))
                lbl.pack()
                ctk.CTkLabel(cf, text=a[:12], font=("Segoe UI", 8), text_color=TXT2).pack()
                rm = ctk.CTkButton(cf, text="\u2715", width=16, height=16,
                                    fg_color="transparent", hover_color=DANGER,
                                    font=("Segoe UI", 7), text_color=TXT3, corner_radius=8,
                                    command=lambda x=a: (added.remove(x), added_data.pop(x, None),
                                        update_sel()))
                rm.place(relx=1.0, x=-3, y=0)

        self._onb_update_sel = update_sel

        def load_results(items):
            for w in self._onb_results.winfo_children():
                w.destroy()
            if not items:
                ctk.CTkLabel(self._onb_results, text="No artists found.",
                             font=("Segoe UI", 12), text_color=TXT3).pack(pady=10)
                return
            for x in items:
                aname = x["artistName"]
                art = x.get("artworkUrl100", "") or x.get("artworkUrl60", "")
                genre = x.get("primaryGenreName", "")
                img = None
                if art:
                    img = self._make_circular(art.replace("100x100", "80x80"), (56, 56))
                row = ctk.CTkFrame(self._onb_results, fg_color=CARD, corner_radius=10)
                row.pack(fill=tk.X, pady=2)
                row.grid_columnconfigure(2, weight=1)
                ilbl = ctk.CTkLabel(row, text="", image=img, width=42, height=42,
                                    corner_radius=21) if img else ctk.CTkLabel(row, text="\U0001F3B5", font=("Segoe UI", 18))
                ilbl.grid(row=0, column=0, rowspan=2, padx=(8, 8), pady=6)
                ctk.CTkLabel(row, text=aname, font=("Segoe UI", 13, "bold"),
                             text_color=TXT).grid(row=0, column=1, sticky="w")
                if genre:
                    ctk.CTkLabel(row, text=genre, font=("Segoe UI", 10),
                                 text_color=TXT3).grid(row=1, column=1, sticky="w")
                def pick(n=aname, u=art, g=genre):
                    if n in added:
                        return
                    added.append(n)
                    added_data[n] = {"img_url": u, "genre": g}
                    update_sel()
                    threading.Thread(target=lambda: self._onb_related(n, g, added), daemon=True).start()
                ctk.CTkButton(row, text="+", width=30, height=30,
                              fg_color=GREEN, hover_color="#1aa34a",
                              text_color="#000000", corner_radius=8,
                              font=("Segoe UI", 14, "bold"),
                              command=pick).grid(row=0, column=2, rowspan=2, padx=(0, 8))

        btn = ctk.CTkButton(sf, text="Search", width=70, height=38,
                            fg_color=GREEN, hover_color="#1aa34a",
                            text_color="#000000", corner_radius=10,
                            font=("Segoe UI", 12))
        btn.grid(row=0, column=1)

        def do_search():
            q = e.get().strip()
            if not q:
                return
            btn.configure(state=tk.DISABLED, text="...")
            def fetch():
                try:
                    r = requests.get(f"{ITUNES}/search", params={"term": q, "entity": "musicArtist", "limit": 8}, timeout=8)
                    items = r.json().get("results", [])
                except:
                    items = []
                self.root.after(0, lambda: (btn.configure(state=tk.NORMAL, text="Search"), load_results(items)))
            threading.Thread(target=fetch, daemon=True).start()

        btn.configure(command=do_search)
        e.bind("<Return>", lambda ev: do_search())

        # Bottom bar
        bottom = ctk.CTkFrame(parent, fg_color="transparent")
        bottom.grid(row=1, column=0, sticky="ew")
        ctk.CTkFrame(bottom, height=1, fg_color=TXT3, corner_radius=0).pack(fill=tk.X, pady=(4, 6))

        def done():
            if len(added) < 3:
                messagebox.showwarning("Artists", "Add at least 3 artists first.", parent=win)
                return
            self._finish_onboarding(win, languages, added, container)

        ctk.CTkButton(bottom, text="Generate My Mixes  \u2192", command=done,
                      fg_color=GREEN, hover_color="#1aa34a", text_color="#000000",
                      font=("Segoe UI", 15, "bold"), corner_radius=14, height=46).pack(pady=(0, 4))

        update_sel()

    def _onb_clear_results(self):
        for w in self._onb_results.winfo_children():
            w.destroy()
        for w in self._onb_suggest.winfo_children():
            w.destroy()

    def _onb_related(self, artist, genre, added):
        if not genre:
            return
        try:
            r = requests.get(f"{ITUNES}/search", params={"term": genre, "entity": "musicArtist", "limit": 8}, timeout=8)
            items = r.json().get("results", [])
        except:
            return
        related = [x for x in items if x["artistName"] != artist
                   and x["artistName"] not in added]
        if not related:
            return
        self.root.after(0, lambda: self._onb_show_related(related, added))

    def _onb_show_related(self, related, added):
        for w in self._onb_suggest.winfo_children():
            w.destroy()
        ctk.CTkLabel(self._onb_suggest, text="You might also like \u2193",
                     font=("Segoe UI", 11, "bold"), text_color=TXT2).pack(anchor="w", pady=(4, 4))
        for x in related:
            aname = x["artistName"]
            art = x.get("artworkUrl100", "") or x.get("artworkUrl60", "")
            genre = x.get("primaryGenreName", "")
            img = None
            if art:
                img = self._make_circular(art.replace("100x100", "80x80"), (56, 56))
            row = ctk.CTkFrame(self._onb_suggest, fg_color=CARD, corner_radius=10)
            row.pack(fill=tk.X, pady=2)
            row.grid_columnconfigure(2, weight=1)
            ilbl = ctk.CTkLabel(row, text="", image=img, width=42, height=42,
                                corner_radius=21) if img else ctk.CTkLabel(row, text="\U0001F3B5", font=("Segoe UI", 18))
            ilbl.grid(row=0, column=0, rowspan=2, padx=(8, 8), pady=6)
            ctk.CTkLabel(row, text=aname, font=("Segoe UI", 13, "bold"),
                         text_color=TXT).grid(row=0, column=1, sticky="w")
            if genre:
                ctk.CTkLabel(row, text=genre, font=("Segoe UI", 10),
                             text_color=TXT3).grid(row=1, column=1, sticky="w")
            def pick(n=aname, u=art, g=genre):
                if n in self._onb_added:
                    return
                self._onb_added.append(n)
                self._onb_added_data[n] = {"img_url": u, "genre": g}
                self._onb_update_sel()
            ctk.CTkButton(row, text="+", width=30, height=30,
                          fg_color=GREEN, hover_color="#1aa34a",
                          text_color="#000000", corner_radius=8,
                          font=("Segoe UI", 14, "bold"),
                          command=pick).grid(row=0, column=2, rowspan=2, padx=(0, 8))

    def _finish_onboarding(self, win, languages, artists, container):
        name = f"{artists[0]} Fan" if artists else "Listener"
        c = self.db.execute("INSERT INTO profiles (name, languages, fav_artists) VALUES (?,?,?)",
                            (name, json.dumps(languages), json.dumps(artists)))
        self.profile_id = c.lastrowid
        self.profile_languages = languages
        self.profile_artists = artists
        self.db.commit()
        win.destroy()

        # Show generating state
        gen = ctk.CTkToplevel(self.root)
        gen.title("Generating your mixes...")
        gen.geometry("400x200")
        gen.transient(self.root)
        gen.grab_set()
        ctk.CTkLabel(gen, text="\U0001F3B6", font=("Segoe UI", 32)).pack(pady=(24, 8))
        gl = ctk.CTkLabel(gen, text="Creating your personalized playlists...",
                         font=("Segoe UI", 15), text_color=TXT2)
        gl.pack(pady=(0, 16))

        def generate():
            self._generate_playlists()
            self.root.after(0, lambda: (gen.destroy(), self._refresh_sidebar_playlists(), self._refresh_home_mixes()))

        threading.Thread(target=generate, daemon=True).start()

    def _generate_playlists(self):
        conn = sqlite3.connect(DB_PATH)
        conn.execute("DELETE FROM playlist_tracks WHERE playlist_id IN "
                      "(SELECT id FROM playlists WHERE profile_id=?)", (self.profile_id,))
        conn.execute("DELETE FROM playlists WHERE profile_id=?", (self.profile_id,))

        all_artists = self.profile_artists
        genre_map = {}
        artist_songs = {}

        # Phase 1: fetch artist info + top songs
        for artist in all_artists:
            try:
                r = requests.get(f"{ITUNES}/search", params={"term": artist, "entity": "song", "limit": 15}, timeout=10)
                songs = r.json().get("results", [])
                genre = ""
                for s in songs:
                    if s.get("artistName", "").lower() == artist.lower():
                        g = s.get("primaryGenreName", "") or s.get("genre", "")
                        if g:
                            genre = g
                            break
                if not genre and songs:
                    genre = songs[0].get("primaryGenreName", "")
                genre_map[artist] = genre or "Pop"
                artist_songs[artist] = songs[:10]
            except:
                genre_map[artist] = "Pop"
                artist_songs[artist] = []

        # Phase 2: create per-artist playlists
        for artist in all_artists:
            songs = artist_songs.get(artist, [])
            if songs:
                pl_name = f"{artist} Favorites"
                c = conn.execute("INSERT INTO playlists (profile_id, name, source) VALUES (?,?,?)",
                                 (self.profile_id, pl_name, "artist"))
                pl_id = c.lastrowid
                for i, s in enumerate(songs[:10]):
                    conn.execute("""INSERT INTO playlist_tracks 
                        (playlist_id, title, artist, album, art_url, position) VALUES (?,?,?,?,?,?)""",
                        (pl_id, s["trackName"], s.get("artistName",""), s.get("collectionName",""),
                         s.get("artworkUrl100",""), i))

        # Phase 3: genre-grouped playlists
        genre_groups = {}
        for artist, genre in genre_map.items():
            genre_groups.setdefault(genre, []).extend(
                [s for s in artist_songs.get(artist, []) if s.get("primaryGenreName","") == genre or True])

        for genre, songs in genre_groups.items():
            if songs:
                pl_name = f"{genre} Mix"
                c = conn.execute("INSERT INTO playlists (profile_id, name, source) VALUES (?,?,?)",
                                 (self.profile_id, pl_name, "genre"))
                pl_id = c.lastrowid
                dedup = set()
                idx = 0
                for s in songs:
                    key = (s["trackName"], s.get("artistName",""))
                    if key not in dedup and idx < 20:
                        dedup.add(key)
                        conn.execute("""INSERT INTO playlist_tracks 
                            (playlist_id, title, artist, album, art_url, position) VALUES (?,?,?,?,?,?)""",
                            (pl_id, s["trackName"], s.get("artistName",""), s.get("collectionName",""),
                             s.get("artworkUrl100",""), idx))
                        idx += 1

        # Phase 4: discover — fetch more from same genres
        if genre_map:
            top_genre = max(set(genre_map.values()), key=list(genre_map.values()).count)
            try:
                r = requests.get(f"{ITUNES}/search", params={"term": top_genre, "entity": "song", "limit": 25}, timeout=10)
                discover = r.json().get("results", [])
                if discover:
                    c = conn.execute("INSERT INTO playlists (profile_id, name, source) VALUES (?,?,?)",
                                     (self.profile_id, "Discover Weekly", "discover"))
                    pl_id = c.lastrowid
                    dedup = set()
                    idx = 0
                    for s in discover:
                        key = (s["trackName"], s.get("artistName",""))
                        if key not in dedup and idx < 25:
                            dedup.add(key)
                            conn.execute("""INSERT INTO playlist_tracks 
                                (playlist_id, title, artist, album, art_url, position) VALUES (?,?,?,?,?,?)""",
                                (pl_id, s["trackName"], s.get("artistName",""), s.get("collectionName",""),
                                 s.get("artworkUrl100",""), idx))
                            idx += 1
            except:
                pass

        conn.commit()
        conn.close()

    def _refresh_sidebar_playlists(self):
        c = self.db.execute(
            "SELECT id, name FROM playlists WHERE profile_id=? ORDER BY id", (self.profile_id,))
        pls = c.fetchall()
        for w in self.sidebar_plf.winfo_children():
            w.destroy()
        if not pls:
            return
        label = ctk.CTkLabel(self.sidebar_plf, text="YOUR MIXES", font=("Segoe UI", 10, "bold"),
                             text_color=TXT3)
        label.pack(anchor="w", padx=10, pady=(4, 6))
        for pl_id, pl_name in pls:
            btn = ctk.CTkButton(self.sidebar_plf, text=f"\u266B  {pl_name}", anchor="w", height=32,
                                fg_color="transparent", hover_color=HOVER,
                                font=("Segoe UI", 12), text_color=TXT2, corner_radius=6,
                                command=lambda pid=pl_id: self._open_playlist(pid))
            btn.pack(fill=tk.X, padx=8, pady=1)

    def _open_playlist(self, pl_id):
        c = self.db.execute(
            "SELECT title, artist, album, art_url FROM playlist_tracks WHERE playlist_id=? ORDER BY position",
            (pl_id,))
        tracks = c.fetchall()
        win = ctk.CTkToplevel(self.root)
        win.title("Playlist")
        win.geometry("600x450")
        win.transient(self.root)
        win.grab_set()

        ctk.CTkLabel(win, text="Playlist Tracks", font=("Segoe UI", 18, "bold"),
                     text_color=TXT).pack(pady=(14, 10))

        sf = ctk.CTkScrollableFrame(win, fg_color="transparent")
        sf.pack(fill=tk.BOTH, expand=True, padx=16, pady=(0, 12))

        for i, (title, artist, album, art_url) in enumerate(tracks):
            r = ctk.CTkFrame(sf, fg_color=CARD, corner_radius=8)
            r.pack(fill=tk.X, pady=2)
            r.grid_columnconfigure(1, weight=1)
            idx_lbl = ctk.CTkLabel(r, text=str(i+1), width=30, font=("Segoe UI", 11),
                                    text_color=TXT3)
            idx_lbl.grid(row=0, column=0, rowspan=2, padx=(10, 6))
            ctk.CTkLabel(r, text=title, font=("Segoe UI", 13, "bold"),
                         text_color=TXT, anchor="w").grid(row=0, column=1, sticky="w", padx=(0, 8))
            ctk.CTkLabel(r, text=f"{artist}  \u00b7  {album}" if album else artist,
                         font=("Segoe UI", 11), text_color=TXT3, anchor="w").grid(row=1, column=1, sticky="w", padx=(0, 8))
            play_btn = ctk.CTkButton(r, text="\u25b6", width=32, height=28,
                                      fg_color=GREEN, hover_color="#1aa34a",
                                      text_color="#000000", corner_radius=8,
                                      font=("Segoe UI", 10, "bold"),
                                      command=lambda t=title, a=artist, al=album, au=art_url:
                                          self._enqueue(t, a, al, au))
            play_btn.grid(row=0, column=2, rowspan=2, padx=(0, 10))

        ctk.CTkButton(win, text="Queue All", command=lambda: (
            [self._enqueue(t, a, al, au) for t, a, al, au in tracks],
            win.destroy()),
            fg_color=GREEN, hover_color="#1aa34a", text_color="#000000",
            corner_radius=14, font=("Segoe UI", 13, "bold")).pack(pady=(0, 14))

    def run(self):
        self.root.mainloop()

if __name__ == "__main__":
    App().run()
