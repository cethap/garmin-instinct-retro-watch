import Toybox.Lang;

// Pure, device-independent helpers used by RetroInstinctView and its unit tests.
module RetroFormat {

    // Honors the device 12/24h setting; both modes keep the leading zero (08:16).
    function formatHour(hour as Number, is24Hour as Boolean) as String {
        if (!is24Hour) {
            hour = hour % 12;
            if (hour == 0) {
                hour = 12;
            }
        }
        return hour.format("%02d");
    }

    // 9876 -> "9876", 12345 -> "12.3K", 123456 -> "123K", null -> "--".
    // Integer math truncates, so the value never rounds above the real count.
    function formatSteps(steps) as String {
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

    // Rounds SystemStats.battery to a whole percentage clamped to 0..100.
    function batteryPercent(battery as Float) as Number {
        var percent = (battery + 0.5).toNumber();
        if (percent > 100) {
            return 100;
        }
        if (percent < 0) {
            return 0;
        }
        return percent;
    }

    // Width of the 28 px battery fill for a 0..100 percentage, rounded to the nearest pixel.
    function batteryFillWidth(percent as Number) as Number {
        return (28 * percent + 50) / 100;
    }

    // Filled segments (0..10) of the step-goal meter; 0 when steps or goal are unknown.
    function stepMeterSegments(steps, goal) as Number {
        if (steps == null || goal == null || goal <= 0) {
            return 0;
        }
        var filled = steps * 10 / goal;
        if (filled > 10) {
            return 10;
        }
        return filled;
    }
}
