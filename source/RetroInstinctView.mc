import Toybox.Activity;
import Toybox.Graphics;
import Toybox.Lang;
import Toybox.System;
import Toybox.WatchUi;
import Toybox.Time;
import Toybox.Time.Gregorian;
import Toybox.ActivityMonitor;
import Toybox.Timer;

// Length of the wrist-raise intro animation, in milliseconds.
const INTRO_MS = 1500;
// Upper bound of the high-power window after a wake (the system uses about ten seconds).
const AWAKE_MS = 10000;

class RetroInstinctView extends WatchUi.WatchFace {

    var fontBig;
    var fontSmall;
    var footprintIcon;
    var heartIcon;
    var yeshuaLogo;
    var crossIcon;
    var vignette;
    var dayNames as Array<String>;
    var dateX;
    var dateY;
    var ringRadius;
    var boltIcon;
    var phoneOffIcon;
    var hrFallback;
    var hrFallbackMinute;
    var animTimer;
    var introStart;
    var awakeUntil;
    var introLayer;
    var introLayerReady;

    function initialize() {
        WatchFace.initialize();
        // Built once instead of on every onUpdate().
        dayNames = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"];
        // 1-bit pixel art: one bitmask per row, most significant bit is the left pixel.
        boltIcon = [0x0E, 0x1C, 0x38, 0x70, 0xFE, 0x7F, 0x0E, 0x1C, 0x38, 0x70, 0x60, 0x80]; // 8x12
        hrFallback = "--";
        hrFallbackMinute = -1;
        awakeUntil = 0;
        introLayerReady = false;
        phoneOffIcon = [0x1FE, 0x3FF, 0x303, 0x34B, 0x333, 0x333, 0x34B, 0x303, 0x303, 0x3FF, 0x3CF, 0x1FE]; // 10x12
    }

    // Load resources and resolve the date position once
    function onLayout(dc as Dc) as Void {
        fontBig = WatchUi.loadResource(Rez.Fonts.RetroBig);
        fontSmall = WatchUi.loadResource(Rez.Fonts.RetroSmall);
        footprintIcon = WatchUi.loadResource(Rez.Drawables.FootprintIcon);
        heartIcon = WatchUi.loadResource(Rez.Drawables.HeartIcon);
        yeshuaLogo = WatchUi.loadResource(Rez.Drawables.Yeshua);
        crossIcon = WatchUi.loadResource(Rez.Drawables.CrossIcon);
        vignette = WatchUi.loadResource(Rez.Drawables.Vignette);

        // Center the date and the step ring in the subscreen; fall back to the Instinct 2 geometry.
        dateX = dc.getWidth() - 32;
        dateY = 30;
        ringRadius = 26;
        if (WatchUi has :getSubscreen) {
            var subscreen = WatchUi.getSubscreen();
            if (subscreen != null) {
                dateX = subscreen.x + subscreen.width / 2;
                dateY = subscreen.y + subscreen.height / 2;
                ringRadius = subscreen.width / 2 - 5; // keeps the 3px stroke clear of the bezel
            }
        }
    }

    function onShow() as Void {
        startIntro();
    }

    function onHide() as Void {
        stopAnimation();
    }

    // Raising the wrist: high-power mode allows timers and animations for about ten seconds.
    function onExitSleep() as Void {
        startIntro();
    }

    // Back to low power: no timers or animations, so settle on the static face.
    function onEnterSleep() as Void {
        awakeUntil = 0;
        stopAnimation();
        introStart = null;
        WatchUi.requestUpdate();
    }

    // Timer callback: redraw until the intro is over, then stop the timer and free the intro layer.
    function onAnimationTick() as Void {
        if (introStart == null || System.getTimer() - introStart >= INTRO_MS) {
            stopAnimation();
            introLayer = null;
        }
        WatchUi.requestUpdate();
    }

    private function startIntro() as Void {
        stopAnimation();
        introStart = System.getTimer();
        awakeUntil = introStart + AWAKE_MS;
        introLayerReady = false;
        if (animTimer == null) {
            animTimer = new Timer.Timer();
        }
        animTimer.start(method(:onAnimationTick), 50, true);
    }

    private function stopAnimation() as Void {
        if (animTimer != null) {
            animTimer.stop();
        }
    }

    function onUpdate(dc as Dc) as Void {
        var w = dc.getWidth();
        var h = dc.getHeight();
        var centerX = w / 2;
        var centerY = h / 2;

        // Intro progress: 0..1 during the wrist-raise animation, 1 once it is over or asleep.
        var progress = 1.0;
        if (introStart != null) {
            progress = RetroFormat.introProgress(System.getTimer() - introStart, INTRO_MS);
        }

        // During the intro the static face comes from a layer rendered once, so each frame only
        // redraws the animated parts. A full render per frame is too slow on the device.
        var layer = null;
        if (progress < 1.0) {
            layer = getIntroLayer(w, h);
        }
        if (layer != null) {
            dc.drawBitmap(0, 0, layer);
        } else {
            dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_BLACK);
            dc.clear();
            dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
            // The vignette goes under the face so the outlined values stay on top of its dots.
            drawVignette(dc, w, centerY, progress);
            drawStaticFace(dc);
        }
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        if (layer != null) {
            drawVignette(dc, w, centerY, progress);
        }

        // Animated parts: the step ring draws itself and charges up to the real progress, and the
        // cross rays grow, then pulse (full, half, off, half) while the watch is awake.
        var activityInfo = ActivityMonitor.getInfo();
        var ringSegments = RetroFormat.stepMeterSegments(activityInfo.steps, activityInfo.stepGoal);
        drawStepRing(dc, dateX, dateY, ringRadius, RetroFormat.animatedCount(ringSegments, progress), RetroFormat.animatedCount(10, progress));
        drawCrossRays(dc, centerX - 15, centerY + 32, RetroFormat.rayScale(progress, System.getTimer(), awakeUntil, System.getClockTime().sec));
    }

    // Static face for the intro, rendered once per intro into an opaque layer that uses the device
    // palette (a smaller palette rejects the transparent bitmaps drawn into it). Returns null when the
    // layer is not available, so the caller falls back to a full render.
    private function getIntroLayer(w as Number, h as Number) {
        if (introLayer == null) {
            var options = {:width => w, :height => h};
            if (Graphics has :createBufferedBitmap) {
                introLayer = Graphics.createBufferedBitmap(options);
            } else {
                introLayer = new Graphics.BufferedBitmap(options);
            }
            introLayerReady = false;
        }
        var bitmap = introLayer;
        if (bitmap has :get) {
            bitmap = bitmap.get(); // API 4+ returns a reference the system may purge
        }
        if (bitmap == null) {
            introLayer = null;
            return null;
        }
        if (!introLayerReady) {
            var layerDc = bitmap.getDc();
            layerDc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_BLACK);
            layerDc.clear();
            layerDc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
            drawStaticFace(layerDc);
            introLayerReady = true;
        }
        return bitmap;
    }

    // Dithered vignette that fades in toward the round bottom edge (176x60, precomputed so it
    // costs one drawBitmap). During the intro it is revealed from the bottom up.
    private function drawVignette(dc as Dc, w as Number, centerY as Number, progress as Float) as Void {
        var rows = RetroFormat.animatedCount(60, progress);
        if (rows > 0) {
            dc.setClip(0, centerY + 88 - rows, w, rows);
            dc.drawBitmap(0, centerY + 28, vignette);
            dc.clearClip();
        }
    }

    // Everything that does not animate: time, date, status row, logo, stats, cross body, phone icon.
    private function drawStaticFace(dc as Dc) as Void {
        var w = dc.getWidth();
        var h = dc.getHeight();
        var centerX = w / 2;
        var centerY = h / 2;

        // --- DATA FETCHING ---
        var activityInfo = ActivityMonitor.getInfo();
        var sysStats = System.getSystemStats();
        var settings = System.getDeviceSettings();
        var clock = System.getClockTime();
        var now = Time.now();

        // --- TIME (Center, Large) ---
        var timeStr = Lang.format("$1$:$2$", [RetroFormat.formatHour(clock.hour, settings.is24Hour), clock.min.format("%02d")]);
        dc.drawText(centerX, centerY + 12, fontBig, timeStr, Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);

        // --- DATE (Subscreen, Small) ---
        var info = Gregorian.info(now, Time.FORMAT_SHORT);
        var dateStr = Lang.format("$1$\n$2$", [getDayName(info.day_of_week), info.day.format("%02d")]);
        // Center the ink, not the text box, inside the ring: each glyph leaves one empty column
        // on its right, and the two lines are 23px of ink (12px line + 11px glyph).
        dc.drawText(dateX + 1, dateY - 11, fontSmall, dateStr, Graphics.TEXT_JUSTIFY_CENTER);

        // --- TOP AREA (left of the subscreen) ---
        // A centered status row where the round display is narrow, then the logo filling the
        // widest band down to the time (about 3px clear of the display edge).
        var charging = (sysStats has :charging) && sysStats.charging;
        drawStatusRow(dc, centerX - 26, 10, RetroFormat.batteryPercent(sysStats.battery), charging);
        dc.drawBitmap(centerX - 90, 29, yeshuaLogo); // 112x46

        // --- STATS ROW (Bottom) ---
        // Layout: Steps (Left) | HR (Right), 32x32 icons above their values

        var iconTop = centerY + 31;
        var textY = centerY + 72;
        var spacing = 30; // Column offset from center; leaves room for the cross between the columns

        // 1. STEPS (Left)
        var stepStr = RetroFormat.formatSteps(activityInfo.steps);

        // Draw Footprint Icon
        dc.drawBitmap(centerX - spacing - 16, iconTop, footprintIcon);
        drawOutlinedText(dc, centerX - spacing, textY, stepStr);

        // 2. HEART RATE (Right)
        // Draw Heart Icon
        dc.drawBitmap(centerX + spacing - 16, iconTop, heartIcon);

        // 3. Radiant cross body between the two columns (31x30); its rays are animated in onUpdate.
        dc.drawBitmap(centerX - 15, iconTop + 1, crossIcon);

        // Phone-disconnected icon in the empty band right of the heart
        if (!settings.phoneConnected) {
            drawPixelArt(dc, centerX + 52, iconTop + 10, phoneOffIcon, 10);
        }
        drawOutlinedText(dc, centerX + spacing, textY, getHeartRate(now.value() / 60));
    }

    // Light rays around the cross at (x, y): two horizontal and four diagonal, length scaled 0..1.
    private function drawCrossRays(dc as Dc, x as Number, y as Number, scale as Float) as Void {
        var side = RetroFormat.animatedCount(5, scale);
        var diagonal = RetroFormat.animatedCount(4, scale);
        if (side > 0) {
            dc.fillRectangle(x + 6 - side, y + 8, side, 1);
            dc.fillRectangle(x + 25, y + 8, side, 1);
        }
        for (var k = 0; k < diagonal; k++) {
            dc.drawPoint(x + 11 - k, y + 5 - k);
            dc.drawPoint(x + 19 + k, y + 5 - k);
            dc.drawPoint(x + 11 - k, y + 12 + k);
            dc.drawPoint(x + 19 + k, y + 12 + k);
        }
    }

    // White text with a 1px black outline, so it stays readable over the dotted vignette.
    private function drawOutlinedText(dc as Dc, x as Number, y as Number, text as String) as Void {
        var justify = Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER;
        dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_TRANSPARENT);
        for (var dy = -1; dy <= 1; dy++) {
            for (var dx = -1; dx <= 1; dx++) {
                if (dx != 0 || dy != 0) {
                    dc.drawText(x + dx, y + dy, fontSmall, text, justify);
                }
            }
        }
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        dc.drawText(x, y, fontSmall, text, justify);
    }

    // Status row centered on x: mini battery, then the percentage; a bolt replaces "%" while charging.
    private function drawStatusRow(dc as Dc, x as Number, y as Number, percent as Number, charging as Boolean) as Void {
        var label = charging ? percent.format("%d") : percent.format("%d") + "%";
        var labelWidth = dc.getTextWidthInPixels(label, fontSmall);
        var left = x - (28 + labelWidth + (charging ? 10 : 0)) / 2;
        drawMiniBattery(dc, left, y, percent);
        dc.drawText(left + 28, y, fontSmall, label, Graphics.TEXT_JUSTIFY_LEFT);
        if (charging) {
            drawPixelArt(dc, left + 30 + labelWidth, y, boltIcon, 8);
        }
    }

    // 24x12 pixel battery: 22x12 body with a 2px border, 16x6 proportional fill and a 2x6 terminal.
    // Drawn with primitives so no battery bitmaps stay loaded in memory.
    private function drawMiniBattery(dc as Dc, x as Number, y as Number, percent as Number) as Void {
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(x, y, 22, 12);
        dc.fillRectangle(x + 22, y + 3, 2, 6);
        dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(x + 2, y + 2, 18, 8);
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        var fill = RetroFormat.batteryFillWidth(percent, 16);
        if (fill > 0) {
            dc.fillRectangle(x + 3, y + 3, fill, 6);
        }
    }

    // Segmented step-goal ring around the date: 10 arcs clockwise from 12 o'clock.
    // Reached segments are 3px thick; the rest stay as a 1px track. Only the first `visible` are drawn.
    private function drawStepRing(dc as Dc, x as Number, y as Number, radius as Number, filled as Number, visible as Number) as Void {
        for (var i = 0; i < visible; i++) {
            dc.setPenWidth(i < filled ? 3 : 1);
            dc.drawArc(x, y, radius, Graphics.ARC_CLOCKWISE, RetroFormat.ringSegmentStart(i), RetroFormat.ringSegmentEnd(i));
        }
        dc.setPenWidth(1);
    }

    // Draws 1-bit pixel art as horizontal runs, one fillRectangle per run.
    private function drawPixelArt(dc as Dc, x as Number, y as Number, rows as Array<Number>, width as Number) as Void {
        for (var j = 0; j < rows.size(); j++) {
            var row = rows[j];
            var runStart = -1;
            for (var i = 0; i <= width; i++) {
                var on = i < width && ((row >> (width - 1 - i)) & 1) == 1;
                if (on && runStart < 0) {
                    runStart = i;
                } else if (!on && runStart >= 0) {
                    dc.fillRectangle(x + runStart, y + j, i - runStart, 1);
                    runStart = -1;
                }
            }
        }
    }

    // Live HR on every update; the history fallback is re-read at most once per minute,
    // since onUpdate() runs every second in high-power mode. "--" when off-wrist.
    // minuteKey is the epoch minute, so a cached value never matches the same minute of another hour.
    private function getHeartRate(minuteKey as Number) as String {
        var activity = Activity.getActivityInfo();
        if (activity != null) {
            var liveHr = activity.currentHeartRate;
            if (liveHr != null) {
                hrFallbackMinute = -1; // the next fallback read must be fresh
                return liveHr.format("%d");
            }
        }
        if (minuteKey != hrFallbackMinute) {
            hrFallback = readHeartRateHistory();
            hrFallbackMinute = minuteKey;
        }
        return hrFallback;
    }

    // Newest valid heart-rate history sample, or "--".
    private function readHeartRateHistory() as String {
        if (ActivityMonitor has :getHeartRateHistory) {
            var history = ActivityMonitor.getHeartRateHistory(1, true);
            if (history != null) {
                var sample = history.next();
                if (sample != null) {
                    var sampleHr = sample.heartRate;
                    if (sampleHr != null && sampleHr != ActivityMonitor.INVALID_HR_SAMPLE) {
                        return sampleHr.format("%d");
                    }
                }
            }
        }
        return "--";
    }

    // Helper to turn Day Number into Name
    function getDayName(day) {
        return dayNames[day - 1];
    }
}
