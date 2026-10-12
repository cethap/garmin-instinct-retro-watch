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
    var dayNames;

    function initialize() {
        WatchFace.initialize();
        // Built once instead of on every onUpdate().
        dayNames = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"];
    }

    // Load custom pixel fonts
    function onLayout(dc as Dc) as Void {
        fontBig = WatchUi.loadResource(Rez.Fonts.RetroBig);
        fontSmall = WatchUi.loadResource(Rez.Fonts.RetroSmall);
        footprintIcon = WatchUi.loadResource(Rez.Drawables.FootprintIcon);
        heartIcon = WatchUi.loadResource(Rez.Drawables.HeartIcon);
        yeshuaLogo = WatchUi.loadResource(Rez.Drawables.Yeshua);
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
        var timeStr = Lang.format("$1$:$2$", [formatHour(clock.hour, settings.is24Hour), clock.min.format("%02d")]);
        dc.drawText(centerX, centerY+10, fontBig, timeStr, Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);

        // --- DATE (Top Right, Small) ---
        var info = Gregorian.info(now, Time.FORMAT_SHORT);
        var dateStr = Lang.format("$1$\n$2$", [getDayName(info.day_of_week), info.day.format("%02d")]);
        dc.drawText(w - 32, 30, fontSmall, dateStr, Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);

        // --- BATTERY (Top Center, Pixel Icon) ---
        var batPct = (sysStats.battery + 0.5).toNumber();
        if (batPct > 100) {
            batPct = 100;
        } else if (batPct < 0) {
            batPct = 0;
        }
        var batStr = batPct.format("%d") + "%";

        if (sysStats has :batteryInDays && sysStats.batteryInDays != null) {
            batStr += " " + sysStats.batteryInDays.format("%d") + "d";
        }

        // Draw Battery Icon and Text
        // Move icon UP to avoid overlap. centerY is 88.
        dc.drawBitmap(centerX - 55, centerY - 105, yeshuaLogo);
        drawBattery(dc, centerX - 43, centerY - 55, batPct);
        dc.drawText(centerX-25, centerY - 20, fontSmall, batStr, Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);

        // --- STATS ROW (Bottom) ---
        // Layout: Steps (Left) | HR (Right)

        var iconY = centerY + 45;
        var textY = iconY + 25;
        var spacing = 25; // Spacing from center

        // 1. STEPS (Left)
        var stepStr = formatSteps(activityInfo.steps);

        // Draw Footprint Icon
        dc.drawBitmap(centerX - spacing - 16, iconY - 16, footprintIcon);
        dc.drawText(centerX - spacing, textY, fontSmall, stepStr, Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);

        // 2. HEART RATE (Right)
        // Draw Heart Icon
        dc.drawBitmap(centerX + spacing - 16, iconY - 16, heartIcon);
        dc.drawText(centerX + spacing, textY, fontSmall, getHeartRate(), Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
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
        var fill = (28 * percent + 50) / 100;
        if (fill > 0) {
            dc.fillRectangle(x + 6, y + 6, fill, 12);
        }
    }

    // Honors the device 12/24h setting; 12h hours have no leading zero.
    private function formatHour(hour as Number, is24Hour as Boolean) as String {
        if (is24Hour) {
            return hour.format("%02d");
        }
        hour = hour % 12;
        if (hour == 0) {
            hour = 12;
        }
        return hour.format("%d");
    }

    // 9876 -> "9876", 12345 -> "12.3K", 123456 -> "123K", null -> "--".
    // Integer math truncates, so the value never rounds above the real count.
    private function formatSteps(steps) as String {
        if (steps == null) {
            return "--";
        }
        if (steps >= 100000) {
            return (steps / 1000).format("%d") + "K";
        }
        if (steps >= 10000) {
            var tenths = steps / 100;
            return (tenths / 10).format("%d") + "." + (tenths % 10).format("%d") + "K";
        }
        return steps.format("%d");
    }

    // Live HR first; otherwise the newest valid history sample; "--" when off-wrist.
    private function getHeartRate() as String {
        var activity = Activity.getActivityInfo();
        if (activity != null) {
            var liveHr = activity.currentHeartRate;
            if (liveHr != null) {
                return liveHr.format("%d");
            }
        }
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
