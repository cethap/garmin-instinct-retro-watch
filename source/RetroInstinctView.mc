import Toybox.Activity;
import Toybox.Graphics;
import Toybox.Lang;
import Toybox.System;
import Toybox.WatchUi;
import Toybox.Time;
import Toybox.Time.Gregorian;
import Toybox.ActivityMonitor;

class RetroInstinctView extends WatchUi.WatchFace {

    var fontBig;
    var fontSmall;
    var footprintIcon;
    var heartIcon;
    var yeshuaLogo;
    var dayNames as Array<String>;
    var dateX;
    var dateY;
    var ringRadius;
    var boltIcon;
    var phoneOffIcon;
    var hrFallback;
    var hrFallbackMinute;

    function initialize() {
        WatchFace.initialize();
        // Built once instead of on every onUpdate().
        dayNames = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"];
        // 1-bit pixel art: one bitmask per row, most significant bit is the left pixel.
        boltIcon = [0x0E, 0x1C, 0x38, 0x70, 0xFE, 0x7F, 0x0E, 0x1C, 0x38, 0x70, 0x60, 0x80]; // 8x12
        hrFallback = "--";
        hrFallbackMinute = -1;
        phoneOffIcon = [0x1FE, 0x3FF, 0x303, 0x34B, 0x333, 0x333, 0x34B, 0x303, 0x303, 0x3FF, 0x3CF, 0x1FE]; // 10x12
    }

    // Load resources and resolve the date position once
    function onLayout(dc as Dc) as Void {
        fontBig = WatchUi.loadResource(Rez.Fonts.RetroBig);
        fontSmall = WatchUi.loadResource(Rez.Fonts.RetroSmall);
        footprintIcon = WatchUi.loadResource(Rez.Drawables.FootprintIcon);
        heartIcon = WatchUi.loadResource(Rez.Drawables.HeartIcon);
        yeshuaLogo = WatchUi.loadResource(Rez.Drawables.Yeshua);

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

    function onUpdate(dc as Dc) as Void {
        var w = dc.getWidth();
        var h = dc.getHeight();
        var centerX = w / 2;
        var centerY = h / 2;

        // 1. CLEAR BACKGROUND
        dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_BLACK);
        dc.clear();

        // 2. SET DRAW COLOR
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);

        // --- DATA FETCHING ---
        var activityInfo = ActivityMonitor.getInfo();
        var sysStats = System.getSystemStats();
        var settings = System.getDeviceSettings();
        var clock = System.getClockTime();
        var now = Time.now();

        // --- TIME (Center, Large) ---
        var timeStr = Lang.format("$1$:$2$", [RetroFormat.formatHour(clock.hour, settings.is24Hour), clock.min.format("%02d")]);
        dc.drawText(centerX, centerY+10, fontBig, timeStr, Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);

        // --- DATE (Subscreen, Small) ---
        var info = Gregorian.info(now, Time.FORMAT_SHORT);
        var dateStr = Lang.format("$1$\n$2$", [getDayName(info.day_of_week), info.day.format("%02d")]);
        // Center the ink, not the text box, inside the ring: each glyph leaves one empty column
        // on its right, and the two lines are 23px of ink (12px line + 11px glyph).
        dc.drawText(dateX + 1, dateY - 11, fontSmall, dateStr, Graphics.TEXT_JUSTIFY_CENTER);
        drawStepRing(dc, dateX, dateY, ringRadius, RetroFormat.stepMeterSegments(activityInfo.steps, activityInfo.stepGoal));

        // --- BATTERY (Top Center, Pixel Icon) ---
        var batPct = RetroFormat.batteryPercent(sysStats.battery);
        var batStr = batPct.format("%d") + "%";

        if (sysStats has :batteryInDays && sysStats.batteryInDays != null) {
            batStr += " " + sysStats.batteryInDays.format("%d") + "d";
        }

        // Logo, battery and battery text share one column left of the subscreen.
        // Every element is trimmed to its content, so these are real positions.
        var clusterX = centerX - 23;
        dc.drawBitmap(clusterX - 32, 5, yeshuaLogo); // 64x24
        drawBattery(dc, clusterX - 22, 33, batPct); // 44x24 including the terminal
        if (sysStats has :charging && sysStats.charging) {
            drawPixelArt(dc, clusterX + 26, 39, boltIcon, 8); // right of the terminal
        }
        if (!settings.phoneConnected) {
            drawPixelArt(dc, clusterX - 36, 39, phoneOffIcon, 10); // left of the battery
        }
        dc.drawText(clusterX, 68, fontSmall, batStr, Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);

        // --- STATS ROW (Bottom) ---
        // Layout: Steps (Left) | HR (Right), 32x32 icons above their values

        var iconTop = centerY + 29;
        var textY = centerY + 70;
        var spacing = 28; // Column offset from center; keeps "12.3K" clear of the HR value

        // 1. STEPS (Left)
        var stepStr = RetroFormat.formatSteps(activityInfo.steps);

        // Draw Footprint Icon
        dc.drawBitmap(centerX - spacing - 16, iconTop, footprintIcon);
        dc.drawText(centerX - spacing, textY, fontSmall, stepStr, Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);

        // 2. HEART RATE (Right)
        // Draw Heart Icon
        dc.drawBitmap(centerX + spacing - 16, iconTop, heartIcon);
        dc.drawText(centerX + spacing, textY, fontSmall, getHeartRate(now.value() / 60), Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
    }

    // Pixel battery: 40x24 body with a 4px border, 28x12 proportional fill and a 4x12 terminal.
    // Drawn with primitives so no battery bitmaps stay loaded in memory.
    private function drawBattery(dc as Dc, x as Number, y as Number, percent as Number) as Void {
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(x, y, 40, 24);
        dc.fillRectangle(x + 40, y + 6, 4, 12);
        dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(x + 4, y + 4, 32, 16);
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        var fill = RetroFormat.batteryFillWidth(percent);
        if (fill > 0) {
            dc.fillRectangle(x + 6, y + 6, fill, 12);
        }
    }

    // Segmented step-goal ring around the date: 10 arcs clockwise from 12 o'clock.
    // Reached segments are 3px thick; the rest stay as a 1px track.
    private function drawStepRing(dc as Dc, x as Number, y as Number, radius as Number, filled as Number) as Void {
        for (var i = 0; i < 10; i++) {
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
