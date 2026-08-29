# Clip Transcriber — راهنمای کاربر / User Guide

<div dir="rtl">

## فارسی

**زیرنویس‌ساز کلیپ** برای هر کلیپ ویدیویی یک فایل زیرنویس `.srt` کنار همان کلیپ می‌سازد تا بتوانید آن را در DaVinci Resolve وارد کنید.

### نصب (فقط یک بار)

1. فایل `Clip Transcriber.app` را به پوشهٔ **Applications** بکشید.
2. روی برنامه دوبار کلیک کنید. اگر macOS گفت «Apple cannot check it»، **Done** را بزنید، به **System Settings ← Privacy & Security** بروید، پایین صفحه خط «Clip Transcriber was blocked…» را پیدا کنید، **Open Anyway** را بزنید و رمز خود را وارد کنید.
   (این کار فقط بار اول لازم است. macOS برنامه‌هایی را که از App Store نیامده‌اند این‌طور تأیید می‌کند. اگر برنامه از فلش USB کپی شده باشد معمولاً این مرحله اصلاً پیش نمی‌آید.)
3. برنامه را باز کنید و از منوی **Clip Transcriber ▸ Settings…** (یا کلید ⌘,) تنظیمات را باز کنید.
4. در قسمت **کلید API**، کلیدی را که برایتان فرستاده شده بچسبانید و **آزمایش کلید** را بزنید. باید تیک سبز ببینید.
   (برای کسی که کلید را در elevenlabs.io می‌سازد: کلید باید دسترسی **Speech to Text** داشته باشد. دسترسی **User** اختیاری است و فقط برای نمایش اعتبار باقی‌مانده به کار می‌رود.)
5. **زبان گفتار** روی **فارسی** باشد.

### ساخت زیرنویس

1. پوشه‌ای را که کلیپ‌ها در آن هستند روی پنجرهٔ برنامه **رها کنید** (یا ⌘O را بزنید و پوشه را انتخاب کنید). زیرپوشه‌ها هم جست‌وجو می‌شوند.
2. کلیپ‌ها با یک تیک فهرست می‌شوند. آن‌هایی را که می‌خواهید تیک بزنید (یا **انتخاب همه**). کلیپ‌هایی که از قبل زیرنویس دارند خاکستری‌اند و نمی‌شود انتخابشان کرد.
3. **شروع** را بزنید. وضعیت هر کلیپ نشان داده می‌شود: استخراج صدا ← بارگذاری ← تبدیل گفتار به متن ← انجام شد.
4. وقتی تمام شد، کنار هر کلیپ یک فایل `.srt` (و یک `.transcript.json`) هست.

نکته‌ها:
- در طول کار، درِ لپ‌تاپ را نبندید. می‌توانید برنامه را در پس‌زمینه بگذارید و کار دیگری بکنید.
- اگر برنامه بسته شد، دوباره همان پوشه را باز کنید و کلیپ‌های باقی‌مانده را تیک بزنید.
- برای ساخت دوبارهٔ زیرنویس یک کلیپ، فایل `.srt` آن را در Finder پاک کنید؛ فهرست خودبه‌خود به‌روز می‌شود (یا ⌘R را بزنید). اگر فایل `.transcript.json` کلیپ هنوز هست، زیرنویس فوراً و بدون بارگذاری دوباره از روی آن ساخته می‌شود؛ برای اعمال تنظیمات جدید زیرنویس (طول خط، رنگ‌ها) روی کلیپ‌های قبلی هم همین راه را بروید.
- در تنظیمات، بخش **نام‌ها و واژه‌های خاص** را با نام شخصیت‌ها و مکان‌های فیلم پر کنید تا املای آن‌ها درست دربیاید.

### وارد کردن در DaVinci Resolve

در Media Pool راست‌کلیک کنید ← **Import ▸ Subtitle…** ← فایل `.srt` را انتخاب کنید و آن را روی تایم‌لاین بکشید.

</div>

---

## English

**Clip Transcriber** creates an `.srt` subtitle file next to each video clip so it can be imported into DaVinci Resolve.

### Install (once)

1. Drag `Clip Transcriber.app` into **Applications**.
2. Double-click it. If macOS says it *"can't be opened because Apple cannot check it"*, click **Done**, open **System Settings → Privacy & Security**, scroll down to the line *"Clip Transcriber was blocked…"*, click **Open Anyway** and enter your password. (Needed only once; this is how macOS approves apps that don't come from the App Store. If the app was copied from a USB stick this step usually doesn't appear at all.)
3. Launch the app and open **Clip Transcriber ▸ Settings…** (⌘,).
4. Paste the API key you were given into **API key** and press **Test Key** — you should see a green check.
   (For whoever creates the key at elevenlabs.io: it needs the **Speech to Text** permission. The **User** permission is optional — it only lets the app show remaining credits.)
5. Set **Spoken language** to **Persian**.

### Make subtitles

1. **Drop the folder** that contains the clips onto the window (or press ⌘O and pick it). Subfolders are included.
2. Every clip is listed with a checkbox. Tick the ones you want (or **Select All**). Clips that already have subtitles are greyed out.
3. Press **Start**. Each clip goes Extracting audio → Uploading → Transcribing → Done.
4. When it finishes, every clip has an `.srt` (and a `.transcript.json`) beside it.

Tips:
- Keep the laptop lid open while it works; the app can run in the background.
- If the app is closed mid-way, open the same folder again and tick the remaining clips.
- To redo a clip's subtitles, delete its `.srt` in Finder — the list updates by itself (or press ⌘R). If the clip still has its `.transcript.json`, the subtitles are rebuilt from it instantly, without uploading again; that's also how to apply new subtitle settings (line length, colours) to clips you've already done.
- Fill **Names and special words** in Settings with character and place names from the film to get their spelling right.

### Import into DaVinci Resolve

Right-click in the Media Pool → **Import ▸ Subtitle…** → choose the `.srt` and drag it onto the timeline.
