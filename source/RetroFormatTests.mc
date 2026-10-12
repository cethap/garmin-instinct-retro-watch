import Toybox.Lang;
import Toybox.Test;

// Run No Evil unit tests for RetroFormat. They are excluded from debug and release
// executables; run them with a unit-test build in the simulator (monkeydo <prg> instinct2 -t).

(:test)
function formatStepsHandlesNullAndSmallCounts(logger as Logger) as Boolean {
    var unknown = RetroFormat.formatSteps(null);
    var zero = RetroFormat.formatSteps(0);
    var below = RetroFormat.formatSteps(9999);
    logger.debug("null=" + unknown + " 0=" + zero + " 9999=" + below);
    return unknown.equals("--") && zero.equals("0") && below.equals("9999");
}

(:test)
function formatStepsTruncatesToTenthsFrom10K(logger as Logger) as Boolean {
    var lower = RetroFormat.formatSteps(10000);
    var middle = RetroFormat.formatSteps(12345);
    var upper = RetroFormat.formatSteps(99999);
    logger.debug("10000=" + lower + " 12345=" + middle + " 99999=" + upper);
    return lower.equals("10.0K") && middle.equals("12.3K") && upper.equals("99.9K");
}

(:test)
function formatStepsDropsDecimalsFrom100K(logger as Logger) as Boolean {
    var lower = RetroFormat.formatSteps(100000);
    var higher = RetroFormat.formatSteps(123456);
    logger.debug("100000=" + lower + " 123456=" + higher);
    return lower.equals("100K") && higher.equals("123K");
}

(:test)
function formatHourKeepsLeadingZeroIn24h(logger as Logger) as Boolean {
    var midnight = RetroFormat.formatHour(0, true);
    var morning = RetroFormat.formatHour(9, true);
    var afternoon = RetroFormat.formatHour(13, true);
    logger.debug("0=" + midnight + " 9=" + morning + " 13=" + afternoon);
    return midnight.equals("00") && morning.equals("09") && afternoon.equals("13");
}

(:test)
function formatHourWrapsTo12WithLeadingZeroIn12h(logger as Logger) as Boolean {
    var midnight = RetroFormat.formatHour(0, false);
    var morning = RetroFormat.formatHour(8, false);
    var noon = RetroFormat.formatHour(12, false);
    var afternoon = RetroFormat.formatHour(13, false);
    var night = RetroFormat.formatHour(23, false);
    logger.debug("0=" + midnight + " 8=" + morning + " 12=" + noon + " 13=" + afternoon + " 23=" + night);
    return midnight.equals("12") && morning.equals("08") && noon.equals("12") && afternoon.equals("01") && night.equals("11");
}

(:test)
function batteryPercentRoundsAndClamps(logger as Logger) as Boolean {
    var down = RetroFormat.batteryPercent(49.4);
    var up = RetroFormat.batteryPercent(49.6);
    var over = RetroFormat.batteryPercent(101.0);
    var under = RetroFormat.batteryPercent(-3.0);
    logger.debug("49.4=" + down + " 49.6=" + up + " 101=" + over + " -3=" + under);
    return down == 49 && up == 50 && over == 100 && under == 0;
}

(:test)
function batteryFillWidthScalesToMaxWidth(logger as Logger) as Boolean {
    var empty = RetroFormat.batteryFillWidth(0, 16);
    var low = RetroFormat.batteryFillWidth(4, 16);
    var half = RetroFormat.batteryFillWidth(50, 16);
    var full = RetroFormat.batteryFillWidth(100, 16);
    logger.debug("0=" + empty + " 4=" + low + " 50=" + half + " 100=" + full);
    return empty == 0 && low == 1 && half == 8 && full == 16;
}

(:test)
function stepMeterSegmentsHandlesMissingData(logger as Logger) as Boolean {
    var noSteps = RetroFormat.stepMeterSegments(null, 10000);
    var noGoal = RetroFormat.stepMeterSegments(5000, null);
    var zeroGoal = RetroFormat.stepMeterSegments(5000, 0);
    logger.debug("noSteps=" + noSteps + " noGoal=" + noGoal + " zeroGoal=" + zeroGoal);
    return noSteps == 0 && noGoal == 0 && zeroGoal == 0;
}

(:test)
function stepMeterSegmentsFillsInTenthsAndCaps(logger as Logger) as Boolean {
    var none = RetroFormat.stepMeterSegments(999, 10000);
    var one = RetroFormat.stepMeterSegments(1000, 10000);
    var six = RetroFormat.stepMeterSegments(6400, 10000);
    var capped = RetroFormat.stepMeterSegments(25000, 10000);
    logger.debug("999=" + none + " 1000=" + one + " 6400=" + six + " 25000=" + capped);
    return none == 0 && one == 1 && six == 6 && capped == 10;
}

(:test)
function stepRingSegmentsStartAtNoonClockwise(logger as Logger) as Boolean {
    var first = [RetroFormat.ringSegmentStart(0), RetroFormat.ringSegmentEnd(0)];
    var wrap = [RetroFormat.ringSegmentStart(3), RetroFormat.ringSegmentEnd(3)];
    var last = [RetroFormat.ringSegmentStart(9), RetroFormat.ringSegmentEnd(9)];
    logger.debug("0=" + first + " 3=" + wrap + " 9=" + last);
    return first[0] == 87 && first[1] == 57
        && wrap[0] == 339 && wrap[1] == 309
        && last[0] == 123 && last[1] == 93;
}

(:test)
function introProgressEasesOutAndClamps(logger as Logger) as Boolean {
    var start = RetroFormat.introProgress(0, 800);
    var half = RetroFormat.introProgress(400, 800);
    var done = RetroFormat.introProgress(800, 800);
    var late = RetroFormat.introProgress(5000, 800);
    logger.debug("0=" + start + " 400=" + half + " 800=" + done + " 5000=" + late);
    return start == 0.0 && half == 0.75 && done == 1.0 && late == 1.0;
}

(:test)
function animatedCountScalesWithProgress(logger as Logger) as Boolean {
    var none = RetroFormat.animatedCount(6, 0.0);
    var half = RetroFormat.animatedCount(6, 0.5);
    var full = RetroFormat.animatedCount(6, 1.0);
    var rays = RetroFormat.animatedCount(5, 0.75);
    logger.debug("0=" + none + " 0.5=" + half + " 1=" + full + " 5@0.75=" + rays);
    return none == 0 && half == 3 && full == 6 && rays == 4;
}

(:test)
function twinkleScaleCyclesEveryFourSeconds(logger as Logger) as Boolean {
    var s0 = RetroFormat.twinkleScale(0);
    var s1 = RetroFormat.twinkleScale(1);
    var s2 = RetroFormat.twinkleScale(2);
    var s3 = RetroFormat.twinkleScale(3);
    var s7 = RetroFormat.twinkleScale(7);
    logger.debug("0=" + s0 + " 1=" + s1 + " 2=" + s2 + " 3=" + s3 + " 7=" + s7);
    return s0 == 1.0 && s1 == 0.5 && s2 == 0.0 && s3 == 0.5 && s7 == 0.5;
}
