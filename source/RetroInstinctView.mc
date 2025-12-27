import Toybox.Graphics;
import Toybox.Lang;
import Toybox.System;
import Toybox.WatchUi;
import Toybox.Time;
import Toybox.Time.Gregorian;
import Toybox.ActivityMonitor;
import Toybox.SensorHistory;

class RetroInstinctView extends WatchUi.WatchFace {

    var fontBig;
    var fontSmall;
    var footprintIcon;
    var heartIcon;
    var yeshuaLogo;
    var bat0;
    var bat15;
    var bat30;
    var bat45;
    var bat60;
    var bat75;
    var bat90;
    var bat100;

    var lastHr = "--";
    var lastHrMin = -1;

    function initialize() {
        WatchFace.initialize();
    }

    // Load custom pixel fonts
    function onLayout(dc as Dc) as Void {
        fontBig = WatchUi.loadResource(Rez.Fonts.RetroBig);
        fontSmall = WatchUi.loadResource(Rez.Fonts.RetroSmall);
        footprintIcon = WatchUi.loadResource(Rez.Drawables.FootprintIcon);
        heartIcon = WatchUi.loadResource(Rez.Drawables.HeartIcon);
        yeshuaLogo = WatchUi.loadResource(Rez.Drawables.Yeshua);

        bat0 = WatchUi.loadResource(Rez.Drawables.Battery0);
        bat15 = WatchUi.loadResource(Rez.Drawables.Battery15);
        bat30 = WatchUi.loadResource(Rez.Drawables.Battery30);
        bat45 = WatchUi.loadResource(Rez.Drawables.Battery45);
        bat60 = WatchUi.loadResource(Rez.Drawables.Battery60);
        bat75 = WatchUi.loadResource(Rez.Drawables.Battery75);
        bat90 = WatchUi.loadResource(Rez.Drawables.Battery90);
        bat100 = WatchUi.loadResource(Rez.Drawables.Battery100);
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
        var clock = System.getClockTime();
        var now = Time.now();

        // --- TIME (Center, Large) ---
        var timeStr = Lang.format("$1$:$2$", [clock.hour.format("%02d"), clock.min.format("%02d")]);
        dc.drawText(centerX, centerY+10, fontBig, timeStr, Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);

        // --- DATE (Top Right, Small) ---
        var info = Gregorian.info(now, Time.FORMAT_SHORT);
        var dateStr = Lang.format("$1$\n$2$", [getDayName(info.day_of_week), info.day.format("%02d")]);
        dc.drawText(w - 32, 30, fontSmall, dateStr, Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);

        // --- BATTERY (Top Center, Dynamic Icon) ---
        var batVal = sysStats.battery;
        var batStr = batVal.format("%d") + "%";

        if (sysStats has :batteryInDays && sysStats.batteryInDays != null) {
            batStr += " " + sysStats.batteryInDays.format("%d") + "d";
        }
        
        var batIcon;
        if (batVal < 8) {
            batIcon = bat0;
        } else if (batVal < 23) {
            batIcon = bat15;
        } else if (batVal < 38) {
            batIcon = bat30;
        } else if (batVal < 53) {
            batIcon = bat45;
        } else if (batVal < 68) {
            batIcon = bat60;
        } else if (batVal < 83) {
            batIcon = bat75;
        } else if (batVal < 95) {
            batIcon = bat90;
        } else {
            batIcon = bat100;
        }

        // Draw Battery Icon and Text
        // Icon size 64x64 (defined in drawables.xml)
        // Move icon UP to avoid overlap. centerY is 88.
        dc.drawBitmap(centerX - 55, centerY - 105, yeshuaLogo);
        dc.drawBitmap(centerX - 55, centerY - 75, batIcon);
        dc.drawText(centerX-25, centerY - 20, fontSmall, batStr, Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);

        // --- STATS ROW (Bottom) ---
        // Layout: Steps (Left) | HR (Right)
        
        var iconY = centerY + 45;
        var textY = iconY + 25;
        var spacing = 25; // Spacing from center

        // 1. STEPS (Left)
        var steps = activityInfo.steps;
        var stepStr;
        if (steps >= 10000) {
            stepStr = (steps / 1000).format("%.1f") + "K";
        } else {
            stepStr = steps.toString();
        }
        
        // Draw Footprint Icon
        dc.drawBitmap(centerX - spacing - 16, iconY - 16, footprintIcon); 
        dc.drawText(centerX - spacing, textY, fontSmall, stepStr, Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);

        // 2. HEART RATE (Right)
        // Update only once per minute
        if (clock.min != lastHrMin) {
            if (activityInfo has :currentHeartRate && activityInfo.currentHeartRate != null) {
                lastHr = activityInfo.currentHeartRate.toString();
            } else {
                var hrHistory = ActivityMonitor.getHeartRateHistory(1, true);
                if (hrHistory != null) {
                    var sample = hrHistory.next();
                    if (sample != null && sample.heartRate != ActivityMonitor.INVALID_HR_SAMPLE) {
                        lastHr = sample.heartRate.toString();
                    }
                }
            }
            lastHrMin = clock.min;
        }
        
        // Draw Heart Icon
        dc.drawBitmap(centerX + spacing - 16, iconY - 16, heartIcon);
        dc.drawText(centerX + spacing, textY, fontSmall, lastHr, Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
    }

    // Helper to turn Day Number into Name
    function getDayName(day) {
        var names = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"];
        return names[day - 1];
    }
}