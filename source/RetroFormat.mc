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

    // Width of a battery fill of maxWidth px for a 0..100 percentage, rounded to the nearest pixel.
    function batteryFillWidth(percent as Number, maxWidth as Number) as Number {
        return (maxWidth * percent + 50) / 100;
    }

    // Step ring segment i (0..9), clockwise from 12 o'clock: 30 degree arcs with 6 degree gaps,
    // in Dc.drawArc degrees (0 = 3 o'clock, counter-clockwise positive).
    function ringSegmentStart(i as Number) as Number {
        return (90 - i * 36 - 3 + 360) % 360;
    }

    function ringSegmentEnd(i as Number) as Number {
        return (ringSegmentStart(i) - 30 + 360) % 360;
    }

    // Ease-out progress (0.0..1.0) of an animation that started elapsedMs ago and lasts durationMs.
    function introProgress(elapsedMs as Number, durationMs as Number) as Float {
        if (elapsedMs >= durationMs) {
            return 1.0;
        }
        var t = elapsedMs.toFloat() / durationMs;
        return 1.0 - (1.0 - t) * (1.0 - t);
    }

    // How many of total items to show at an animation progress, rounded to the nearest item.
    function animatedCount(total as Number, progress as Float) as Number {
        return (total * progress + 0.5).toNumber();
    }

    // Length scale of the cross rays for a clock second: full, half, off, half (a 4-second pulse).
    function twinkleScale(second as Number) as Float {
        var phase = second % 4;
        if (phase == 0) {
            return 1.0;
        }
        if (phase == 2) {
            return 0.0;
        }
        return 0.5;
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
