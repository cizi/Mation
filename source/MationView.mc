using Toybox.WatchUi;
using Toybox.Graphics as Gfx;
using Toybox.System;
using Toybox.Lang;
using Toybox.Application as App;
using Toybox.Time;
using Toybox.Time.Gregorian;
using Toybox.Math;
using Toybox.Activity;
using Toybox.ActivityMonitor;
using Toybox.SensorHistory;
using Toybox.Application;

class MationView extends WatchUi.WatchFace {

    // const for settings
    const MOON_PHASE = 0;
    const SUNSET_SUNSRISE = 1;
    const FLOORS = 2;
    const CALORIES = 3;
    const STEPS = 4;
    const HR = 5;
    const BATTERY = 6;
    const ALTITUDE = 7;
    const PRESSURE = 8;
    const NEXT_SUN_EVENT = 9;
    const SECOND_TIME = 10;
    const DISABLED = 100;
    const DISTANCE = 11;
    const BATTERY_IN_DAYS = 12;
    const PRESSURE_ARRAY_KEY = "pressure";
    const LOW_PRESSURE = 950;
    const HIGH_PRESSURE = 1050;

    // others
    hidden var settings;
    hidden var app;
    hidden var is240dev;
    hidden var is280dev;
    hidden var secPosX;
    hidden var secPosY;
    hidden var secFontWidth;
    hidden var secFontHeight;
    hidden var uc;
    hidden var smallDialCoordsLines;

    // Sunset / sunrise / moon phase vars
    hidden var sc;
    hidden var sunriseMoment;
    hidden var sunsetMoment;
    hidden var blueAmMoment;
    hidden var bluePmMoment;
    hidden var goldenAmMoment;
    hidden var goldenPmMoment;
    hidden var location = null;
    hidden var moonPhase;

    // night mode
    hidden var frColor = null;
    hidden var bgColor = null;
    hidden var themeColor = null;

    hidden var fntIcons = null;
    hidden var fntDataFields = null;

    hidden var halfWidth = null;
    hidden var field1 = null;
    hidden var field2 = null;
    hidden var field3 = null;
    hidden var field4 = null;
    
    // meters / scales 
    hidden var scaleStartCircle;
    hidden var scaleEndCircle;
    
    // scales meter radiuses
    hidden var startCircle;
    hidden var masterEnd;
    hidden var bigEnd;
    hidden var smallEnd;
    
    hidden var leftScaleMeterCoors;
    hidden var rightScaleMeterCoors;    
    hidden var scaleMeterRadius;
    
    hidden var isAwake;
    hidden var partialUpdatesAllowed;
    hidden var minHandEnd; 
    
    function initialize() {
        WatchFace.initialize();
        app = App.getApp();
        sc = new SunCalc();
        uc = new UiCalc();

        fntIcons = WatchUi.loadResource(Rez.Fonts.fntIcons);
        fntDataFields = WatchUi.loadResource(Rez.Fonts.fntDataFields);
        partialUpdatesAllowed = ( Toybox.WatchUi.WatchFace has :onPartialUpdate );
    }

    // Load your resources here
    function onLayout(dc) {
        setLayout(Rez.Layouts.WatchFace(dc));
        is240dev = (dc.getWidth() == 240);
        is280dev = (dc.getWidth() == 280);

        halfWidth = dc.getWidth() / 2;
        secFontHeight = Gfx.getFontHeight(Gfx.FONT_TINY);
        secFontWidth = (is280dev ? 24 : 22);
        secPosX = dc.getWidth() - 15;
        secPosY = halfWidth - (secFontHeight / 2) - 3;

        field1 = [halfWidth - 35, 76];
        field2 = [50, halfWidth - 4];
        field3 = [(dc.getWidth() - 44), halfWidth - 2];
        field4 = [halfWidth + 6, dc.getWidth() - 66];

        smallDialCoordsLines = uc.calculateSmallDialLines(halfWidth);

        // sun / moon etc. init
        sunriseMoment = null;
        sunsetMoment = null;
        blueAmMoment = null;
        bluePmMoment = null;
        goldenAmMoment = null;
        goldenPmMoment = null;
        moonPhase = null; 
        
        // scales vars
        scaleStartCircle = halfWidth - 12;
        scaleEndCircle = halfWidth - 37;
        
        startCircle = halfWidth - 30;   // radius where starts all scales lines going to the edge of the screen
        masterEnd = startCircle + 12;   // end of the biggiest scale part
        bigEnd = startCircle + 8;       // end of the middle size
        smallEnd = startCircle + 3;     // end of the smallest 
        
        minHandEnd = halfWidth - 15;
        
        leftScaleMeterCoors = uc.calculateScaleMeter(135, 225, halfWidth, startCircle, smallEnd, bigEnd, masterEnd);
        rightScaleMeterCoors = uc.calculateScaleMeter(315, 405, halfWidth, startCircle, smallEnd, bigEnd, masterEnd);
        
        scaleMeterRadius = 120;         // FENIX 6X (280x280)
        if ((is240dev == false) && (is280dev == false)) {
            scaleMeterRadius = 110;     // FENIX 6 (260x260)
        } else if (is240dev) {
            scaleMeterRadius = 100;     // others (240x240)
        }
        
        isAwake = true;
    }

    // Called when this View is brought to the foreground. Restore
    // the state of this View and prepare it to be shown. This includes
    // loading resources into memory.
    function onShow() {
    }

    // Update the view
    function onUpdate(dc) {
        if (dc has :clearClip) {    // Clear any partial update clipping.
            dc.clearClip();
        }

        var now = Time.now();
        var today = Gregorian.info(now, Time.FORMAT_MEDIUM);
        // if don't have the sun times load it if from position or load again in midnight
        if ((sunriseMoment == null) || (sunsetMoment == null)) {
            reloadSuntimes(now);    // calculate for current date
        }

        // the values are known, need to find last sun event for today and recalculated the first which will come tomorrow
        if ((sunriseMoment != null) && (sunsetMoment != null) && (location != null)) {
            var lastSunEventInDayMoment = (App.getApp().getProperty("ShowGoldenBlueHours") ? bluePmMoment : sunsetMoment);
            var nowWithOneMinute = now.add(new Time.Duration(60));
            // if sunrise moment is in past && is after last sunevent (bluePmMoment / sunsetMoment) need to recalculate
            if ((nowWithOneMinute.compare(sunriseMoment) > 0) && (nowWithOneMinute.compare(lastSunEventInDayMoment) > 0)) { // is time to recalculte?
                var nowWithOneDay = now.add(new Time.Duration(Gregorian.SECONDS_PER_DAY));
                reloadSuntimes(nowWithOneDay);
            }
        }

        // Call the parent onUpdate function to redraw the layout
        View.onUpdate(dc);
        settings = System.getDeviceSettings();
        var isNight = checkIfNightMode(sunriseMoment, sunsetMoment, new Time.Moment(now.value()));  // needs to by firts bucause of isNight variable
        if (isNight) {
            frColor = 0x000000;
            bgColor = 0xFFFFFF;
            themeColor = (App.getApp().getProperty("NightModeTheme") ? App.getApp().getProperty("NightModeThemeColor") : App.getApp().getProperty("DaylightProgess"));
        } else {
            frColor = App.getApp().getProperty("ForegroundColor");
            bgColor = App.getApp().getProperty("BackgroundColor");
            themeColor = App.getApp().getProperty("DaylightProgess");
        }

        drawDial(dc, today);                                    // main dial

        // DATE
        if (App.getApp().getProperty("DateFormat") != DISABLED) {
            var dateString = getFormatedDate();
            var moonCentering = 0;
            if (App.getApp().getProperty("ShowMoonPhaseBeforeDate")) {
                today = Gregorian.info(Time.now(), Time.FORMAT_SHORT);
                var dateWidth = dc.getTextWidthInPixels(dateString, Gfx.FONT_TINY);
                moonCentering = 14;
                drawMoonPhase(halfWidth - (dateWidth / 2) - 6, 198, dc, getMoonPhase(today), 0);
            }
            dc.setColor(themeColor, Gfx.COLOR_TRANSPARENT);
            dc.drawText(halfWidth + moonCentering, (dc.getWidth() * 0.66).toNumber(), Gfx.FONT_TINY, dateString.toUpper(), Gfx.TEXT_JUSTIFY_CENTER);
        }       
        
        // second time calculation and dial drawing if any
        var secondTime = calculateSecondTime(new Time.Moment(now.value()));
        
        drawMeter(dc, 135, 225, true); // LEFT
        drawPressureToMeter(dc);
        
        drawMeter(dc, 315, 405, false); // RIGHT
        drawAltToMeter(dc);
         
        var field0 = [field1[0] + 12, field1[1] + 8]; 
        drawDataField(STEPS, 1, field0, today, secondTime, dc);    
        drawDataField(SUNSET_SUNSRISE, 1, field1, today, secondTime, dc);  // FIELD 1 - App.getApp().getProperty("Opt1")
        drawDataField(PRESSURE, 2, field2, today, secondTime, dc);  // FIELD 2 - App.getApp().getProperty("Opt2")
        drawDataField(ALTITUDE, 3, field3, today, secondTime, dc);  // FIELD 3 - App.getApp().getProperty("Opt3")
        if (App.getApp().getProperty("ShowBatteryInDays")) {
            drawDataField(BATTERY_IN_DAYS, 4, field4, today, secondTime, dc);  // FIELD 4 - App.getApp().getProperty("Opt4")
        } else {
            drawDataField(BATTERY, 4, field4, today, secondTime, dc);  // FIELD 4 - App.getApp().getProperty("Opt4")
        }    
        
        if (App.getApp().getProperty("ShowNotificationAndConnection")) {
            drawBtConnection(dc);
            drawNotification(dc);
        }
        if (App.getApp().getProperty("AlarmIndicator")) {
            drawBell(dc);
        }    
        
        // TIME 
        drawClockHands(dc, today);
        
        // Logging pressure history each hour and only if I don't have the value already logged
        var lastPressureLoggingTimeHistoty = (app.getProperty("lastPressureLoggingTimeHistoty") == null ? null : app.getProperty("lastPressureLoggingTimeHistoty").toNumber());
        if ((today.min == 0) && (today.hour != lastPressureLoggingTimeHistoty)) {
            handlePressureHistorty(getPressure());
            app.setProperty("lastPressureLoggingTimeHistoty", today.hour);
        }  
        
        
        if (false) { // TODO (partialUpdatesAllowed) {
            // If this device supports partial updates and they are currently
            // allowed run the onPartialUpdate method to draw the second hand.
            onPartialUpdate( dc );
        } else if (isAwake) {
            drawSecondHand(dc, today, minHandEnd);
        }
          
    }
    
    
    function drawClockHands(dc, time) {
        var hr = (time.hour >= 12 ? time.hour - 12 : time.hour) - 3;
        var pen = 4;
        var handsAngle = 3;
        var handCenterCircle = 7;
        var hrHandEnd = halfWidth - 65;
        var handSemiEnd = halfWidth - (is240dev ? 85 : 100);  // white part circle
        
        dc.setColor(App.getApp().getProperty("HandsBottomColor"), Gfx.COLOR_TRANSPARENT);
        dc.fillCircle(halfWidth, halfWidth, 9);
        
        var hrAngle = ((hr + (time.min.toFloat() / 60)) * 30);
        var hrCoef = hrAngle + handsAngle;
        var angleDeg = (hrCoef * Math.PI) / 180;
        var hrHandX1 = ((hrHandEnd * Math.cos(angleDeg)) + halfWidth);
        var hrHandY1 = ((hrHandEnd * Math.sin(angleDeg)) + halfWidth);
        
        hrCoef = hrAngle + 270;
        angleDeg = (hrCoef * Math.PI) / 180;
        var hrHandX3 = ((handCenterCircle * Math.cos(angleDeg)) + halfWidth);
        var hrHandY3 = ((handCenterCircle * Math.sin(angleDeg)) + halfWidth);
        
        hrCoef = hrAngle - handsAngle;
        angleDeg = (hrCoef * Math.PI) / 180;
        var hrHandX2 = ((hrHandEnd * Math.cos(angleDeg)) + halfWidth);
        var hrHandY2 = ((hrHandEnd * Math.sin(angleDeg)) + halfWidth);
        
        hrCoef = hrAngle + 90;
        angleDeg = (hrCoef * Math.PI) / 180;
        var hrHandX4 = ((handCenterCircle * Math.cos(angleDeg)) + halfWidth);
        var hrHandY4 = ((handCenterCircle * Math.sin(angleDeg)) + halfWidth);
        
        dc.setPenWidth(pen);
        dc.drawLine(hrHandX1, hrHandY1, hrHandX4, hrHandY4);
        dc.drawLine(hrHandX2, hrHandY2, hrHandX3, hrHandY3);
                
        hrCoef = hrAngle + (handsAngle * 3);
        angleDeg = (hrCoef * Math.PI) / 180;
        var hrHandX5 = ((handSemiEnd * Math.cos(angleDeg)) + halfWidth);
        var hrHandY5 = ((handSemiEnd * Math.sin(angleDeg)) + halfWidth);
        
        hrCoef = hrAngle - (handsAngle * 3);
        angleDeg = (hrCoef * Math.PI) / 180;
        var hrHandX6 = ((handSemiEnd * Math.cos(angleDeg)) + halfWidth);
        var hrHandY6 = ((handSemiEnd * Math.sin(angleDeg)) + halfWidth);
        
        dc.setColor(frColor, Gfx.COLOR_TRANSPARENT);
        dc.fillPolygon([[hrHandX1, hrHandY1], [hrHandX2, hrHandY2], [hrHandX6, hrHandY6], [hrHandX5, hrHandY5]]);
        dc.drawLine(hrHandX1, hrHandY1, hrHandX2, hrHandY2);
        dc.drawLine(hrHandX1, hrHandY1, hrHandX5, hrHandY5);
        dc.drawLine(hrHandX2, hrHandY2, hrHandX6, hrHandY6);
        
        // minutes
        handsAngle = 2;
        dc.setColor(App.getApp().getProperty("HandsBottomColor"), Gfx.COLOR_TRANSPARENT);       
           
        var minAngle = (time.min * 6) - 90;
        var minCoef = minAngle + handsAngle;
        
        angleDeg = (minCoef * Math.PI) / 180;
        var minHandX1 = ((minHandEnd * Math.cos(angleDeg)) + halfWidth);
        var minHandY1 = ((minHandEnd * Math.sin(angleDeg)) + halfWidth);

        minCoef = minAngle + 270;
        angleDeg = (minCoef * Math.PI) / 180;
        var minHandX3 = ((handCenterCircle * Math.cos(angleDeg)) + halfWidth);
        var minHandY3 = ((handCenterCircle * Math.sin(angleDeg)) + halfWidth);
        
        minCoef = minAngle - handsAngle;
        angleDeg = (minCoef * Math.PI) / 180;
        var minHandX2 = ((minHandEnd * Math.cos(angleDeg)) + halfWidth);
        var minHandY2 = ((minHandEnd * Math.sin(angleDeg)) + halfWidth);
        
        minCoef = minAngle + 90;
        angleDeg = (minCoef * Math.PI) / 180;
        var minHandX4 = ((handCenterCircle * Math.cos(angleDeg)) + halfWidth);
        var minHandY4 = ((handCenterCircle * Math.sin(angleDeg)) + halfWidth);

        dc.drawLine(minHandX1, minHandY1, minHandX4, minHandY4);
        dc.drawLine(minHandX2, minHandY2, minHandX3, minHandY3);
        
        minCoef = minAngle + (handsAngle * 3);
        angleDeg = (minCoef * Math.PI) / 180;
        var minHandX5 = ((handSemiEnd * Math.cos(angleDeg)) + halfWidth);
        var minHandY5 = ((handSemiEnd * Math.sin(angleDeg)) + halfWidth);
        
        minCoef = minAngle - (handsAngle * 3);
        angleDeg = (minCoef * Math.PI) / 180;
        var minHandX6 = ((handSemiEnd * Math.cos(angleDeg)) + halfWidth);
        var minHandY6 = ((handSemiEnd * Math.sin(angleDeg)) + halfWidth);
        
        dc.setColor(frColor, Gfx.COLOR_TRANSPARENT);
        dc.fillPolygon([[minHandX1, minHandY1], [minHandX2, minHandY2], [minHandX6, minHandY6], [minHandX5, minHandY5]]);
        
        dc.drawLine(minHandX1, minHandY1, minHandX2, minHandY2);
        dc.drawLine(minHandX1, minHandY1, minHandX5, minHandY5);
        dc.drawLine(minHandX2, minHandY2, minHandX6, minHandY6);
    }
    
    
    function drawSecondHand(dc, time, radius) {
        // seconds
        if (App.getApp().getProperty("ShowSeconds")) {
            var secAngle = (time.sec * 6) - 90;
            var angleDeg = (secAngle * Math.PI) / 180;
            var secHandX1 = ((radius * Math.cos(angleDeg)) + halfWidth);
            var secHandY1 = ((radius * Math.sin(angleDeg)) + halfWidth);
            
            secAngle = (time.sec * 6) + 90;
            angleDeg = (secAngle * Math.PI) / 180;
            var secHandX2 = ((20 * Math.cos(angleDeg)) + halfWidth);
            var secHandY2 = ((20 * Math.sin(angleDeg)) + halfWidth);
            
            dc.setColor(themeColor, Gfx.COLOR_TRANSPARENT);
            dc.drawLine(secHandX2, secHandY2, secHandX1, secHandY1);
        }
    }


    function onPartialUpdate(dc) {
        if (App.getApp().getProperty("ShowSeconds")) {
            // dc.clear();
            // dc.setColor(frColor, bgColor);
            // drawSecondHand(dc, System.getClockTime(), minHandEnd);
        }
    }


    // Called when this View is removed from the screen. Save the
    // state of this View here. This includes freeing resources from
    // memory.
    function onHide() {
    }

    // The user has just looked at their watch. Timers and animations may be started here.
    function onExitSleep() {
        isAwake = true;
    }

    // Terminate any active timers and prepare for slow updates.
    function onEnterSleep() {
        isAwake = false;
        WatchUi.requestUpdate();
    }
    
    
    // Draw data field by params. One function do all the fields by coordinates and position
    function drawDataField(dataFiled, position, fieldCors, today, secondTime, dc) {
        switch (dataFiled) {
            case MOON_PHASE:
            today = Gregorian.info(Time.now(), Time.FORMAT_SHORT);
            drawMoonPhase(halfWidth, (dc.getHeight() / 5).toNumber(), dc, getMoonPhase(today), position);
            break;

            case SUNSET_SUNSRISE:
            drawSunsetSunriseTime(fieldCors[0], fieldCors[1], dc, position);
            break;

            case NEXT_SUN_EVENT:
            drawNextSunTime(fieldCors[0], fieldCors[1], dc, position);
            break;

            case BATTERY:
            drawBattery(fieldCors[0], fieldCors[1], dc, position, today, false);
            break;
            
            case BATTERY_IN_DAYS:
            drawBattery(fieldCors[0], fieldCors[1], dc, position, today, true);
            break;

            case HR:
            drawHr(fieldCors[0], fieldCors[1], dc, position);
            break;

            case PRESSURE:
            drawPressure(fieldCors[0], fieldCors[1], dc, getPressure(), today, position);
            break;

            case STEPS:
            drawSteps(fieldCors[0], fieldCors[1], dc, position);
            break;
            
            case DISTANCE:
            drawDistance(fieldCors[0], fieldCors[1], dc, position);
            break;

            case ALTITUDE:
            drawAltitude(fieldCors[0], fieldCors[1], dc, position);
            break;

            case FLOORS:
            drawFloors(fieldCors[0], fieldCors[1], dc, position);
            break;

            case CALORIES:
            drawCalories(fieldCors[0], fieldCors[1], dc, position);
            break;
            
            case SECOND_TIME:
            drawSecondTime(fieldCors[0], fieldCors[1], dc, secondTime, position);
            break;
        }
    }
    
    
    // Calculate second time from setting option
    // returns Gregorian Info
    function calculateSecondTime(todayMoment) {
        var utcOffset = System.getClockTime().timeZoneOffset * -1;
        var utcMoment = todayMoment.add(new Time.Duration(utcOffset));
        var secondTimeMoment = utcMoment.add(new Time.Duration(App.getApp().getProperty("SecondTimeUtcOffset")));
        
        return sc.momentToInfo(secondTimeMoment);
    }
    
    
    // Draw second time liek a data field
    function drawSecondTime(xPos, yPos, dc, secondTime, position) {
        if (position == 1) {
            xPos += 24;
            yPos -= 17;
        }
        if (position == 2) {
            xPos += 21;
        }
        if (position == 3) {
            xPos -= (is280dev ? -2 : (is240dev ? 9 : 3));
        }
        if (position == 4) {
            xPos -= ((is240dev == false) && (is280dev == false) ? 9 : 5);
        }
        var value = getFormattedTime(secondTime.hour, secondTime.min);
        value = value[:formatted] + value[:amPm];
        dc.setColor(frColor, Gfx.COLOR_TRANSPARENT);
        dc.drawText(xPos, yPos, fntDataFields, value, Gfx.TEXT_JUSTIFY_CENTER);
    }

    // Load or refresh the sun times
    function reloadSuntimes(now) {
        var suntimes = getSunTimes(now);
        sunriseMoment = suntimes[:sunrise];
        sunsetMoment = suntimes[:sunset];
        blueAmMoment = suntimes[:blueAm];
        bluePmMoment = suntimes[:bluePm];
        goldenAmMoment = suntimes[:goldenAm];
        goldenPmMoment = suntimes[:goldenPm];
    }

    // Draw current HR
    function drawHr(xPos, yPos, dc, position) {
        if (position == 1) {
            xPos += 44;
            yPos = (is240dev ? yPos - 18 : yPos - 16);
        }
        if ((position == 2) && is240dev) {
            xPos += 42;
        } else if ((position == 2) && is280dev) {
            xPos += 47;
        } else if (position == 2) {
            xPos += 37;
        }
        if ((position == 3) || (position == 4)) {
            xPos += 11;
        }
        dc.setColor(themeColor, Gfx.COLOR_TRANSPARENT);
        dc.drawText(xPos - 44, yPos - 3, fntIcons, "3", Gfx.TEXT_JUSTIFY_LEFT);

        dc.setColor(frColor, Gfx.COLOR_TRANSPARENT);
        var hr = "--";
        if (Activity.getActivityInfo().currentHeartRate != null) {
            hr = Activity.getActivityInfo().currentHeartRate.toString();
        }
        dc.drawText(xPos - 19, yPos, fntDataFields, hr, Gfx.TEXT_JUSTIFY_LEFT);
    }


    // calculate sunset and sunrise times based on location
    // return array of moments
    function getSunTimes(now) {
        // Get today's sunrise/sunset times in current time zone.
        var sunrise = null;
        var sunset = null;
        var blueAm = null;
        var bluePm = null;
        var goldenAm = null;
        var goldenPm = null;

        location = Activity.getActivityInfo().currentLocation;
        if (location) {
            location = Activity.getActivityInfo().currentLocation.toRadians();
            app.setProperty("location", location);
        } else {
            location =  app.getProperty("location");
        }

         if (location != null) {
            sunrise = sc.calculate(now, location, SUNRISE);
            sunset = sc.calculate(now, location, SUNSET);

            blueAm = sc.calculate(now, location, BLUE_HOUR_AM);
            bluePm = sc.calculate(now, location, BLUE_HOUR_PM);

            goldenAm = sc.calculate(now, location, GOLDEN_HOUR_AM);
            goldenPm = sc.calculate(now, location, GOLDEN_HOUR_PM);
        }

        return {
            :sunrise => sunrise,
            :sunset => sunset,
            :blueAm => blueAm,
            :bluePm => bluePm,
            :goldenAm => goldenAm,
            :goldenPm => goldenPm
        };
    }


    // draw next sun event
    function drawNextSunTime(xPos, yPos, dc, position) {
        if (location != null) {
            if (position == 1) {
                xPos -= 6;
            }
            if (position == 4) {
                xPos -= 38;
                yPos += 14;
            }

            if ((sunriseMoment != null) && (sunsetMoment != null)) {
                var nextSunEvent = 0;
                var now = new Time.Moment(Time.now().value());
                // Convert to same format as sunTimes, for easier comparison. Add a minute, so that e.g. if sun rises at
                // 07:38:17, then 07:38 is already consided daytime (seconds not shown to user).
                now = now.add(new Time.Duration(60));

                if (blueAmMoment.compare(now) > 0) {            // Before blue hour today: today's blue hour is next.
                    nextSunEvent = sc.momentToInfo(blueAmMoment);
                    drawSun(xPos, yPos, dc, false, App.getApp().getProperty("BlueHourColor"));
                } else if (sunriseMoment.compare(now) > 0) {        // Before sunrise today: today's sunrise is next.
                    nextSunEvent = sc.momentToInfo(sunriseMoment);
                    drawSun(xPos, yPos, dc, false, App.getApp().getProperty("GoldenHourColor"));
                } else if (goldenAmMoment.compare(now) > 0) {
                    nextSunEvent = sc.momentToInfo(goldenAmMoment);
                    drawSun(xPos, yPos, dc, false, themeColor);
                } else if (goldenPmMoment.compare(now) > 0) {
                    nextSunEvent = sc.momentToInfo(goldenPmMoment);
                    drawSun(xPos, yPos, dc, true, App.getApp().getProperty("GoldenHourColor"));
                } else if (sunsetMoment.compare(now) > 0) { // After sunrise today, before sunset today: today's sunset is next.
                    nextSunEvent = sc.momentToInfo(sunsetMoment);
                    drawSun(xPos, yPos, dc, true, App.getApp().getProperty("BlueHourColor"));
                } else {    // This is here just for sure if some time condition won't meet the timing
                            // comparation. It menas I will force calculate the next event, the rest will be updated in
                            // the next program iteration - After sunset today: tomorrow's blue hour (if any) is next.
                    now = now.add(new Time.Duration(Gregorian.SECONDS_PER_DAY));
                    var blueHrAm = sc.calculate(now, location, BLUE_HOUR_AM);
                    nextSunEvent = sc.momentToInfo(blueHrAm);
                    drawSun(xPos, yPos, dc, false, App.getApp().getProperty("BlueHourColor"));
                }

                var value = getFormattedTime(nextSunEvent.hour, nextSunEvent.min); // App.getApp().getFormattedTime(hour, min);
                value = value[:formatted] + value[:amPm];
                dc.setColor(frColor, Gfx.COLOR_TRANSPARENT);
                dc.drawText(xPos + 21, yPos - 15, fntDataFields, value, Gfx.TEXT_JUSTIFY_LEFT);
            }
        }
    }


    // draw next sun event
    function drawSunsetSunriseTime(xPos, yPos, dc, position) {
        if (location != null) {


            var now = new Time.Moment(Time.now().value());
            if ((sunriseMoment != null) && (sunsetMoment != null)) {
                var nextSunEvent = 0;
                // Convert to same format as sunTimes, for easier comparison. Add a minute, so that e.g. if sun rises at
                // 07:38:17, then 07:38 is already consided daytime (seconds not shown to user).
                now = now.add(new Time.Duration(60));

                // Before sunrise today: today's sunrise is next.
                if (sunriseMoment.compare(now) > 0) {       // now < sc.momentToInfo(sunrise)
                    nextSunEvent = sc.momentToInfo(sunriseMoment);
                    drawSun(xPos, yPos, dc, false, frColor);
                    // After sunrise today, before sunset today: today's sunset is next.
                } else if (sunsetMoment.compare(now) > 0) { // now < sc.momentToInfo(sunset)
                    nextSunEvent = sc.momentToInfo(sunsetMoment);
                    drawSun(xPos, yPos, dc, true, frColor);
                } else {    // This is here just for sure if some time condition won't meet the timing
                            // comparation. It menas I will force calculate the next event, the rest will be updated in
                            // the next program iteration -  After sunset today: tomorrow's sunrise (if any) is next.
                    now = now.add(new Time.Duration(Gregorian.SECONDS_PER_DAY));
                    var sunrise = sc.calculate(now, location, SUNRISE);
                    nextSunEvent = sc.momentToInfo(sunrise);
                    drawSun(xPos, yPos, dc, false, frColor);
                }

                var value = getFormattedTime(nextSunEvent.hour, nextSunEvent.min); // App.getApp().getFormattedTime(hour, min);
                value = value[:formatted] + value[:amPm];
                dc.setColor(themeColor, Gfx.COLOR_TRANSPARENT);
                //dc.drawText(xPos + 21, yPos - 15, fntDataFields, value, Gfx.TEXT_JUSTIFY_LEFT);
                dc.drawText(xPos + 21, yPos - 21, Gfx.FONT_TINY, value, Gfx.TEXT_JUSTIFY_LEFT);
            }
        }
    }


    // check if night mode on and if is night
    function checkIfNightMode(sunrise, sunset, now) {
        var isNight = false;
        if (App.getApp().getProperty("NightMode") && (sunrise != null) && (sunset != null)) {
            now = now.add(new Time.Duration(60));   // add 1 minute because I need to switch the colors in the next onUpdate iteration
            if (sunrise.compare(now) > 0) {     // Before sunrise today: today's sunrise is next.
                isNight = true;
            } else if (sunset.compare(now) > 0) {   // After sunrise today, before sunset today: today's sunset is next.
                isNight = false;
            } else {    // This is here just for sure if some time condition won't meet the timing
                        // comparation. It menas I will force calculate the next event, the rest will be updated in
                        // the next program iteration -  After sunset today: tomorrow's sunrise (if any) is next.
                isNight = true;
            }
        }

        return isNight;
    }

    // Will draw bell if is alarm set
    function drawBell(dc) {
        if (settings.alarmCount > 0) {
            dc.setColor(frColor, Gfx.COLOR_TRANSPARENT);
            dc.drawText(halfWidth - 10, 25, fntIcons, ":", Gfx.TEXT_JUSTIFY_LEFT);
        }
    }

    // Draw the master dial
    function drawDial(dc, today) {
        var coorsArray = null;

        dc.setColor(bgColor, Gfx.COLOR_TRANSPARENT);    // nmake background
        dc.fillCircle(halfWidth, halfWidth, halfWidth + 1);

        // this part is draw the net over all display
        dc.setColor(frColor, Gfx.COLOR_TRANSPARENT);
        dc.setPenWidth(2);

        for(var angle = 0; angle < 360; angle+=30) {
            if ((angle != 0) && (angle != 90) && (angle != 180) && (angle != 270)) {
                    coorsArray = smallDialCoordsLines.get(angle);
                    dc.drawLine(halfWidth, halfWidth, coorsArray[0], coorsArray[1]);
            }
        }
        // hide the middle of the net to shows just pieces on the edge of the screen
        dc.setColor(bgColor, Gfx.COLOR_TRANSPARENT);
        dc.drawCircle(halfWidth, halfWidth, halfWidth - 1);
        dc.fillCircle(halfWidth, halfWidth, halfWidth - 6);

        // draw the master pieces in 24, 12, 6, 18 hours point
        var masterPointLen = 12;
        var masterPointWid = 4;
        dc.setColor(frColor, Gfx.COLOR_TRANSPARENT);
        dc.setPenWidth(masterPointWid);
        dc.drawLine(halfWidth, 0, halfWidth, masterPointLen);
        dc.drawLine(halfWidth, dc.getWidth(), halfWidth, dc.getWidth() - masterPointLen);
        dc.drawLine(0, halfWidth - (masterPointWid / 2), masterPointLen, halfWidth - (masterPointWid / 2));
        dc.drawLine(dc.getWidth(), halfWidth - (masterPointWid / 2), dc.getWidth() - masterPointLen, halfWidth - (masterPointWid / 2));
    }
    

    // Draw sunset or sunrice image
    function drawSun(posX, posY, dc, up, color) {
        dc.setColor(color, bgColor);
        if (up) {
            dc.drawText(posX - 10, posY - 18, fntIcons, "?", Gfx.TEXT_JUSTIFY_LEFT);
        } else {    // down
            dc.drawText(posX - 10, posY - 18, fntIcons, ">", Gfx.TEXT_JUSTIFY_LEFT);
        }
    }


    // Draw steps info
    function drawSteps(posX, posY, dc, position) {
        if (is240dev) {
            posX -= 6;
        }
        dc.setColor(App.getApp().getProperty("HandsBottomColor"), Gfx.COLOR_TRANSPARENT);
        dc.drawText(posX - 8, posY - 4, fntIcons, "0", Gfx.TEXT_JUSTIFY_LEFT);

        dc.setColor(frColor, Gfx.COLOR_TRANSPARENT);
        var info = ActivityMonitor.getInfo();
        var stepsCount = info.steps;
        if (is240dev && (stepsCount > 999) && ((position == 2) || (position == 3))){
            stepsCount = (info.steps / 1000.0).format("%.1f").toString() + "k";
        }
        // dc.drawText(posX + 22, posY, fntDataFields, stepsCount.toString(), Gfx.TEXT_JUSTIFY_LEFT);
        dc.drawText(posX + 22, posY, Gfx.FONT_XTINY, stepsCount.toString(), Gfx.TEXT_JUSTIFY_LEFT);
    }
    
    
    // Draw steps info
    function drawDistance(posX, posY, dc, position) {
        if (position == 1) {
            posX -= 10;
            posY -= (is240dev ? 18 : 16);
        }
        if (position == 2) {
            posX -= (is240dev ? 6 : (is280dev ? 14 : 4));
        }
        if (position == 3) {
            posX -= (is240dev ? 40 : 36);
        }
        if (position == 4) {
            posX -= (is240dev ? 40 : 41);
        }

        dc.setColor(themeColor, bgColor);
        dc.drawText(posX - 4, posY - 4, fntIcons, "7", Gfx.TEXT_JUSTIFY_LEFT);

        dc.setColor(frColor, Gfx.COLOR_TRANSPARENT);
        var info = ActivityMonitor.getInfo();
        var distanceKm = (info.distance / 100000).format("%.2f");
        if (is280dev || (position == 1) || (position == 4))  {
            distanceKm = distanceKm.toString() + "km";
        }
        dc.drawText(posX + 22, posY, fntDataFields, distanceKm.toString(), Gfx.TEXT_JUSTIFY_LEFT);
    }


    // Draw floors info
    function drawFloors(posX, posY, dc, position) {
        if (position == 1) {
            posX += 2;
            posY = (is240dev ? posY - 18 : posY - 16);
        }
            if (position == 3) {
                posX -= 32;
        }
        if (position == 4) {
            posX = (is240dev ? (posX - 25) : (posX - 28));
        }

        dc.setColor(themeColor, Gfx.COLOR_TRANSPARENT);
        dc.drawText(posX - 4, posY - 4, fntIcons, "1", Gfx.TEXT_JUSTIFY_LEFT);

        dc.setColor(frColor, Gfx.COLOR_TRANSPARENT);
        var info = ActivityMonitor.getInfo();
        dc.drawText(posX + 22, posY, fntDataFields, info.floorsClimbed.toString(), Gfx.TEXT_JUSTIFY_LEFT);
    }


    // Draw calories per day
    function drawCalories(posX, posY, dc, position) {
        if (position == 1) {
            posX -= 2;
            posY = (is240dev ? posY - 18 : posY - 16);
        }
            if (position == 3) {
                posX = (is240dev ? (posX - 38) : (posX - 32));
        }
        if (position == 4) {
            posX = (is240dev ? (posX - 32) : (posX - 32));
        }

        dc.setColor(themeColor, Gfx.COLOR_TRANSPARENT);
        dc.drawText(posX - 2, posY - 4, fntIcons, "6", Gfx.TEXT_JUSTIFY_LEFT);

        dc.setColor(frColor, Gfx.COLOR_TRANSPARENT);
        var info = ActivityMonitor.getInfo();
        var caloriesCount = info.calories;
        if (is240dev && (caloriesCount > 999) && ((position == 2) || (position == 3))){
            caloriesCount = (caloriesCount / 1000.0).format("%.1f").toString() + "M";
        }
        dc.drawText(posX + 20, posY, fntDataFields, caloriesCount.toString(), Gfx.TEXT_JUSTIFY_LEFT);
    }


    // Draw BT connection status
    function drawBtConnection(dc) {
        if ((settings has : phoneConnected) && (settings.phoneConnected)) {
            dc.setColor(Gfx.COLOR_BLUE, Gfx.COLOR_TRANSPARENT);
            dc.drawText(halfWidth - 26, dc.getHeight() - 30, fntIcons, "8", Gfx.TEXT_JUSTIFY_LEFT);
        }
    }


    // Draw notification alarm
    function drawNotification(dc) {
        if ((settings has : notificationCount) && (settings.notificationCount)) {
            dc.setColor(Gfx.COLOR_RED, Gfx.COLOR_TRANSPARENT);
            dc.drawText(halfWidth + 8, dc.getHeight() - 30, fntIcons, "5", Gfx.TEXT_JUSTIFY_LEFT);
        }
    }


    // Returns formated date by settings
    function getFormatedDate() {
        var ret = "";
        if (App.getApp().getProperty("DateFormat") <= 3) {
            var today = Gregorian.info(Time.now(), Time.FORMAT_MEDIUM);
            if (App.getApp().getProperty("DateFormat") == 1) {
                ret = Lang.format("$1$ $2$ $3$", [today.day_of_week, today.day, today.month]);
            } else if (App.getApp().getProperty("DateFormat") == 2) {
                ret = Lang.format("$1$ $2$ $3$", [today.day_of_week, today.month, today.day]);
            } else {
                ret = Lang.format("$1$ $2$", [today.day_of_week, today.day]);
            }
        } else {
            var today = Gregorian.info(Time.now(), Time.FORMAT_SHORT);
            ret = Lang.format("$1$ / $2$", [today.month, today.day]);
        }

        return ret;
    }


    // Draw a moon by phase
    function drawMoonPhase(xPos, yPos, dc, phase, position) {
        var radius = 9;
        if (position == 0) {
            yPos = (is280dev ? yPos + 4 : yPos + 1);
        }
        if (position == 2) {
            xPos = (is280dev ? xPos + 46 : xPos + 38);
            yPos += 11;
        }
        if (position == 3) {
            xPos -= 25;
            yPos += 11;
        }
        if (position == 4) {
            yPos += 8;
            radius = (is240dev ? radius - 1 : radius);
        }

        dc.setColor(frColor, bgColor);
        if (phase == 0) {
            dc.setPenWidth(2);
            dc.drawCircle(xPos, yPos, radius);
        } else {
            dc.fillCircle(xPos, yPos, radius);
            if (phase == 1) {
                dc.setColor(bgColor, frColor);
                dc.fillCircle(xPos - 5, yPos, radius);
                } else if (phase == 2) {
                    dc.setColor(bgColor, frColor);
                dc.fillRectangle(xPos - radius, yPos - radius, radius, (radius * 2) + 2);
                } else if (phase == 3) {
                    dc.setPenWidth(radius - 2);
                    dc.setColor(bgColor, frColor);
                    dc.drawArc(xPos + 5, yPos, radius + 5, Gfx.ARC_CLOCKWISE, 270, 90);
                } else if (phase == 5) {
                    dc.setPenWidth(radius - 2);
                    dc.setColor(bgColor, frColor);
                    dc.drawArc(xPos - 5, yPos, radius + 5, Gfx.ARC_CLOCKWISE, 90, 270);
                } else if (phase == 6) {
                    dc.setColor(bgColor, frColor);
                    dc.fillRectangle(xPos + (radius / 2) - 3, yPos - radius, radius, (radius * 2) + 2);
                } else if (phase == 7) {
                    dc.setColor(bgColor, frColor);
                    dc.fillCircle(xPos + 5, yPos, radius);
                }
        }
    }
    
    function drawMeter(dc, from, to, leftSide) {
        var coords;
        var coord;
        dc.setColor(App.getApp().getProperty("HandsBottomColor"), Gfx.COLOR_TRANSPARENT);     
        if (leftSide == true) {
            coords = leftScaleMeterCoors;
        } else {
            coords = rightScaleMeterCoors;
        }
        
        dc.setPenWidth(2);
        for(var angle = from; angle < to; angle+=3) {
            coord = coords.get(angle);      
            dc.drawLine(coord[0], coord[1], coord[2], coord[3]);
        }
        dc.setColor(Gfx.COLOR_LT_GRAY, bgColor);
        dc.setPenWidth(2);
        for(var angle = from; angle < to; angle+=9) {
            coord = coords.get(angle);      
            dc.drawLine(coord[0], coord[1], coord[2], coord[3]);

        }
        
        dc.setPenWidth(3);
        coord = coords.get(from);      
        dc.drawLine(coord[0], coord[1], coord[2], coord[3]);
        
        coord = coords.get((from + 45));      
        dc.drawLine(coord[0], coord[1], coord[2], coord[3]);
        
        coord = coords.get((from + 90));      
        dc.drawLine(coord[0], coord[1], coord[2], coord[3]);
    }


    // Draw battery witch % state
    function drawBattery(xPos, yPos, dc, position, time, inDays) { 
        if ((is240dev == false) && (is280dev == false)) {
            yPos += 4;
        } else if (is240dev) {
            yPos += 8;
            xPos += 14;
        }
        dc.setPenWidth(1);
        var batteryPercent = System.getSystemStats().battery;
        if (batteryPercent <= 10) {
            dc.setColor(Gfx.COLOR_RED, Gfx.COLOR_TRANSPARENT);
        } else {
            dc.setColor(App.getApp().getProperty("HandsBottomColor"), Gfx.COLOR_TRANSPARENT);
        }
        
        var batteryWidth = 23;
        dc.drawRectangle(xPos - 34, yPos + 4, batteryWidth, 13);    // battery
        // dc.drawRectangle(xPos + batteryWidth - 34, yPos + 8, 2, 5); // battery top
        var batteryColor = App.getApp().getProperty("HandsBottomColor"); //Gfx.COLOR_GREEN;
        if (batteryPercent <= 10) {
            batteryColor = Gfx.COLOR_RED;
        } else if (batteryPercent <= 35) {
            batteryColor = Gfx.COLOR_ORANGE;
        }

        dc.setColor(batteryColor, bgColor);
        var batteryState = ((batteryPercent / 10) * 2).toNumber();
        dc.fillRectangle(xPos - 31, yPos + 7, batteryState - 3, 7);
        
        if (is240dev == false) {
            var batText = batteryPercent.toNumber().toString() + "%";
            dc.setColor(frColor, Gfx.COLOR_TRANSPARENT);
            if (inDays) {
                if (time.min % 10 == 0) {   // battery is calculating each ten minutes (hope in more accurate results)
                    getRemainingBattery(time, batteryPercent);
                }
                batText = (app.getProperty("remainingBattery") == null ? "W8" : app.getProperty("remainingBattery").toString());
            }
            dc.setColor(App.getApp().getProperty("HandsBottomColor"), Gfx.COLOR_TRANSPARENT);
            dc.setColor(frColor, bgColor);  
            dc.drawText(xPos + 12, yPos, Gfx.FONT_XTINY, batText, Gfx.TEXT_JUSTIFY_CENTER);  
        }        
    }
    
    
    // set variable named remainingBattery to remaining battery in days / hours
    function getRemainingBattery(time, batteryPercent) { 
        if (System.getSystemStats().charging) {         // if charging
            app.setProperty("batteryTime", null);
            app.setProperty("remainingBattery", "W8");  // will show up "wait" sign
        } else {
            var bat = app.getProperty("batteryTime");
            if (bat == null) {
                bat = [time.now().value(), batteryPercent];
                app.setProperty("batteryTime", bat);
                app.setProperty("remainingBattery", "W8");    // still waiting for battery
            } else {
                var nowValue = time.now().value(); 
                if (bat[1] > batteryPercent) {
                    var remaining = (bat[1] - batteryPercent).toFloat() / (nowValue - bat[0]).toFloat();
                    remaining = remaining * 60 * 60;    // percent consumption per hour
                    remaining = batteryPercent.toFloat() / remaining;
                    if (remaining > 48) { 
                        remaining = Math.round(remaining / 24).toNumber() + "d";
                    } else {
                        remaining = Math.round(remaining).toNumber() + "h";
                    }
                    app.setProperty("remainingBattery", remaining);
                } 
            }
        }
    }


    // draw altitude
    function drawAltitude(xPos, yPos, dc, position) {
        dc.setColor(frColor, Gfx.COLOR_TRANSPARENT);
        var alt = getAltitude();
        alt = alt[:altitude];
        dc.drawText(xPos, yPos, Gfx.FONT_TINY, alt, Gfx.TEXT_JUSTIFY_RIGHT);

        // coordinates correction text to mountain picture
        xPos = xPos - 6;
        yPos = yPos - 22;
        dc.setPenWidth(2);

        dc.setColor(themeColor, bgColor);
        dc.drawText(xPos, yPos, fntIcons, ";", Gfx.TEXT_JUSTIFY_RIGHT);
    }

    // Draw the pressure state and current pressure
    function drawPressure(xPos, yPos, dc, pressure, today, position) {
        var lastPressureLoggingTime = (app.getProperty("lastPressureLoggingTime") == null ? null : app.getProperty("lastPressureLoggingTime").toNumber());
        if ((today.min == 0) && (today.hour != lastPressureLoggingTime)) {   // grap is redrawning only in whole hour
            var baroFigure = 0;
            var targetPeriod = App.getApp().getProperty("PressureGraphPeriod");
            var pressure3 = app.getProperty(PRESSURE_ARRAY_KEY + targetPeriod.toString());  // last saved value for current setting
            var pressure2 = app.getProperty(PRESSURE_ARRAY_KEY + (targetPeriod / 2).toString());    // middle period for current setting
            var pressure1 = app.getProperty("pressure0");   // always need a current value which is saved on position 0
            var PRESSURE_GRAPH_BORDER = App.getApp().getProperty("PressureGraphBorder");    // pressure border to change the graph in hPa
            if (pressure1 != null) {    // always should have at least pressure1 but test it for sure
                pressure1 = pressure1.toNumber();
                pressure2 = (pressure2 == null ? pressure1 : pressure2.toNumber()); // if still dont have historical data, use the current data
                pressure3 = (pressure3 == null ? pressure1 : pressure3.toNumber());
                if ((pressure3 - pressure2).abs() < PRESSURE_GRAPH_BORDER) {    // baroFigure 1 OR 2
                    if ((pressure2 > pressure1) && ((pressure2 - pressure1) >= PRESSURE_GRAPH_BORDER)) {    // baroFigure 1
                        baroFigure = 1;
                    }
                    if ((pressure1 > pressure2) && ((pressure1 - pressure2) >= PRESSURE_GRAPH_BORDER)) {    // baroFigure 2
                        baroFigure = 2;
                    }
                }
                if ((pressure3 > pressure2) && ((pressure3 - pressure2) >= PRESSURE_GRAPH_BORDER)) {    // baroFigure 3, 4, 5
                    baroFigure = 4;
                    if ((pressure2 > pressure1) && ((pressure2 - pressure1) >= PRESSURE_GRAPH_BORDER)) {    // baroFigure 3
                        baroFigure = 3;
                    }
                    if ((pressure1 > pressure2) && ((pressure1 - pressure2) >= PRESSURE_GRAPH_BORDER)) {    // baroFigure 5
                        baroFigure = 5;
                    }
                }
                if ((pressure2 > pressure3) && ((pressure2 - pressure3) >= PRESSURE_GRAPH_BORDER)) {    // baroFigure 6, 7, 8
                    baroFigure = 7;
                    if ((pressure2 > pressure1) && ((pressure2 - pressure1) >= PRESSURE_GRAPH_BORDER)) {    // FIGIRE 6
                        baroFigure = 6;
                    }
                    if ((pressure1 > pressure2) && ((pressure1 - pressure2) >= PRESSURE_GRAPH_BORDER)) {    // baroFigure 8
                        baroFigure = 8;
                    }
                }
            }
            app.setProperty("lastPressureLoggingTime", today.hour);
            app.setProperty("baroFigure", baroFigure);
        }        
        
        var baroFigure = (app.getProperty("baroFigure") == null ? 0 : app.getProperty("baroFigure").toNumber());
        if (is280dev) {
            xPos += 3;
        }
        drawPressureGraph(xPos, yPos - 3, dc, baroFigure);
        dc.setColor(frColor, Gfx.COLOR_TRANSPARENT);
        dc.drawText(xPos - 6, yPos, Gfx.FONT_TINY, pressure.toString(), Gfx.TEXT_JUSTIFY_LEFT);
    }

    // Draw small pressure graph based on baroFigure
    // 0 - no change during last 8 hours - change don`t hit the PRESSURE_GRAPH_BORDER --
    // 1 - the same first 4 hours, then down -\
    // 2 - the same first 4 hours, then up -/
    // 3 - still down \
    // 4 - going down first 4 hours, then the same \_
    // 5 - going down first 4 house, then up \/
    // 6 - going up for first 4 hours, then down /\
    // 7 - going up for first 4 hours, then the same /-
    // 8 - stil going up /
    function drawPressureGraph(xPos, yPos, dc, figure) {
        dc.setPenWidth(3);
        dc.setColor(themeColor, bgColor);
        switch (figure) {
            case 0:
                dc.drawLine(xPos - 5, yPos, xPos + 27, yPos);
            break;

            case 1:
                dc.drawLine(xPos - 5, yPos - 7, xPos + 11, yPos - 7);
                dc.drawLine(xPos + 11, yPos - 7, xPos + 25, yPos + 7);
            break;

            case 2:
                dc.drawLine(xPos - 5, yPos, xPos + 11, yPos);
                dc.drawLine(xPos + 11, yPos, xPos + 25, yPos - 12);
            break;

            case 3:
                dc.drawLine(xPos - 8, yPos - 12, xPos + 25, yPos + 6);
            break;

            case 4:
                dc.drawLine(xPos -3 , yPos - 12, xPos + 11, yPos);
                dc.drawLine(xPos + 11, yPos, xPos + 27, yPos);
            break;

            case 5:
                dc.drawLine(xPos - 3, yPos - 12, xPos + 11, yPos);
                dc.drawLine(xPos + 11, yPos, xPos + 25, yPos - 12);
            break;

            case 6:
                dc.drawLine(xPos - 5, yPos + 4, xPos + 11, yPos - 8);
                dc.drawLine(xPos + 11, yPos - 8, xPos + 25, yPos + 4);
            break;

            case 7:
                dc.drawLine(xPos - 3, yPos + 6, xPos + 11, yPos - 6);
                dc.drawLine(xPos + 11, yPos - 6, xPos + 27, yPos - 6);
            break;

            case 8:
                dc.drawLine(xPos - 3, yPos + 5, xPos + 25, yPos - 19);
            break;
        }
    }

    // Return a formatted time dictionary that respects is24Hour settings.
    // - hour: 0-23.
    // - min:  0-59.
    function getFormattedTime(hour, min) {
        var amPm = "";
        var amPmFull = "";
        var isMilitary = false;
        var timeFormat = "$1$:$2$";

        if (!System.getDeviceSettings().is24Hour) {
            // #6 Ensure noon is shown as PM.
            var isPm = (hour >= 12);
            if (isPm) {
                // But ensure noon is shown as 12, not 00.
                if (hour > 12) {
                    hour = hour - 12;
                }
                amPm = "p";
                amPmFull = "PM";
            } else {
                // #27 Ensure midnight is shown as 12, not 00.
                if (hour == 0) {
                    hour = 12;
                }
                amPm = "a";
                amPmFull = "AM";
            }
        } else {
            if (App.getApp().getProperty("UseMilitaryFormat")) {
                isMilitary = true;
                timeFormat = "$1$$2$";
                hour = hour.format("%02d");
            }
        }

        return {
            :hour => hour,
            :min => min.format("%02d"),
            :amPm => amPm,
            :amPmFull => amPmFull,
            :isMilitary => isMilitary,
            :formatted => Lang.format(timeFormat, [hour, min.format("%02d")])
        };
    }

    // Return one of 8 moon phase by date
    // Trying to cache for better optimalization, becase calculation is needed once per day (date)
    // 0 => New Moon
    // 1 => Waxing Crescent Moon
    // 2 => Quarter Moon
    // 3 => Waning Gibbous Moon
    // 4 => Full Moon
    // 5 => Waxing Gibbous Moon
    // 6 => Last Quarter Moon
    // 7 => Waning Crescent Moon
    function getMoonPhase(today) {
        if ((moonPhase == null) || ((today.hour == 0) && (today.min == 0))) {
            var year = today.year;
            var month = today.month;
            var day = today.day;
            var c = 0;
            var e = 0;
            var jd = 0;
            var b = 0;

            if (month < 3) {
                year--;
                month += 12;
            }

            ++month;
            c = 365.25 * year;
            e = 30.6 * month;
            jd = c + e + day - 694039.09; //jd is total days elapsed
            jd /= 29.5305882; //divide by the moon cycle
            b = jd.toNumber(); //int(jd) -> b, take integer part of jd
            jd -= b; //subtract integer part to leave fractional part of original jd
            b = Math.round(jd * 8).abs(); //scale fraction from 0-8 and round
            if (b >= 8 ) {
                b = 0; //0 and 8 are the same so turn 8 into 0
            }
            moonPhase = b;
        }

        return moonPhase;
    }

    // Returns altitude info with units
    function getAltitude() {
        // Note that Activity::Info.altitude is supported by CIQ 1.x, but elevation history only on select CIQ 2.x
        // devices.
        var unit = "";
        var sample;
        var value = "";
        var activityInfo = Activity.getActivityInfo();
        var altitude = activityInfo.altitude;
        if ((altitude == null) && (Toybox has :SensorHistory) && (Toybox.SensorHistory has :getElevationHistory)) {
            sample = SensorHistory.getElevationHistory({ :period => 1, :order => SensorHistory.ORDER_NEWEST_FIRST })
                .next();
            if ((sample != null) && (sample.data != null)) {
                altitude = sample.data;
            }
        }
        if (altitude != null) {
            // Metres (no conversion necessary).
            if (settings.elevationUnits == System.UNIT_METRIC) {
                unit = "m";
            // Feet.
            } else {
                altitude *= /* FT_PER_M */ 3.28084;
                unit = "ft";
            }
            value = altitude.format("%d");
        }

        return {
            :altitude => value,
            :unit => unit
        };
    }

    // Returns pressure in hPa
    function getPressure() {
        var pressure = null;
        var value = 0;  // because of some watches not have barometric sensor
        // Avoid using ActivityInfo.ambientPressure, as this bypasses any manual pressure calibration e.g. on Fenix
        // 5. Pressure is unlikely to change frequently, so there isn't the same concern with getting a "live" value,
        // compared with HR. Use SensorHistory only.
        if ((Toybox has :SensorHistory) && (Toybox.SensorHistory has :getPressureHistory)) {
            var sample = SensorHistory.getPressureHistory(null).next();
            if ((sample != null) && (sample.data != null)) {
                pressure = sample.data;
            }
        }

        if (pressure != null) {
            pressure = pressure / 100; // Pa --> hPa;
            value = pressure.format("%.0f"); // + "hPa";
        }

        return value;
    }

    // Each hour is the pressure saved (durring last 8 hours) for creation a simple graph
    // storing 8 variables but working just with 4 right now (8,4.1)
    function handlePressureHistorty(pressureValue) {
        var graphPeriod = App.getApp().getProperty("PressureGraphPeriod");
        var pressures = []; 
        // var pressures = ["pressure0" ....  "pressure8"];
        for(var period = 0; period <= graphPeriod; period+=1) {
            pressures.add(PRESSURE_ARRAY_KEY + period.toString());
        }

        var preindex = -1;
        for(var pressure = pressures.size(); pressure > 1; pressure-=1) {
            preindex = pressure - 2;
            if (preindex >= 0) {
                if (app.getProperty(pressures[preindex]) == null) {
                    app.setProperty(pressures[preindex], pressureValue);
                }
                app.setProperty(pressures[pressure - 1], app.getProperty(pressures[preindex]));             
            }
        }
        app.setProperty("pressure0", pressureValue);
    }
    
    
    function drawPressureToMeter(dc) {
        var xPos = (halfWidth / 2) - 8;
        if (is240dev) {
            xPos += 7;
        }
        dc.setPenWidth(3);
        dc.setColor(App.getApp().getProperty("HandsBottomColor"), Gfx.COLOR_TRANSPARENT);
        dc.drawText(xPos, dc.getHeight() - 60, Gfx.FONT_XTINY, LOW_PRESSURE.toString(), Gfx.TEXT_JUSTIFY_LEFT);
        dc.drawText(xPos, 40, Gfx.FONT_XTINY, HIGH_PRESSURE.toString(), Gfx.TEXT_JUSTIFY_LEFT);
        dc.setColor(themeColor, Gfx.COLOR_TRANSPARENT);
        
        var pressure = getPressure().toFloat();
        if ((pressure >= LOW_PRESSURE) && (pressure <= HIGH_PRESSURE)) {
            var end = 225 - ((pressure - LOW_PRESSURE) * 0.9);
            dc.drawArc(halfWidth, halfWidth, scaleMeterRadius, Gfx.ARC_CLOCKWISE, 225, end);
            
            var endLine = 225 - ((HIGH_PRESSURE - pressure) * 0.9);
            var angleDeg = (endLine * Math.PI) / 180;
            var pointX1 = ((scaleStartCircle * Math.cos(angleDeg)) + halfWidth);
            var pointY1 = ((scaleStartCircle * Math.sin(angleDeg)) + halfWidth);       
            var pointX2 = ((scaleEndCircle * Math.cos(angleDeg)) + halfWidth);
            var pointY2 = ((scaleEndCircle * Math.sin(angleDeg)) + halfWidth);  
            dc.drawLine(pointX1, pointY1, pointX2, pointY2);        
            
            angleDeg = ((endLine + 4) * Math.PI) / 180;
            pointX1 = ((scaleStartCircle * Math.cos(angleDeg)) + halfWidth);
            pointY1 = ((scaleStartCircle * Math.sin(angleDeg)) + halfWidth);       
            pointX2 = ((scaleEndCircle * Math.cos(angleDeg)) + halfWidth);
            pointY2 = ((scaleEndCircle * Math.sin(angleDeg)) + halfWidth);   
            dc.drawLine(pointX1, pointY1, pointX2, pointY2);
        }             
    }
    
    
    function drawAltToMeter(dc) {
        var xPos = dc.getWidth() - 64;
        if ((is240dev == false) && (is280dev == false)) {
            xPos += 4;
        }

        var alt = getAltitude();
        alt = alt[:altitude].toDouble();
        
        var lowAlt = (app.getProperty("lowAlt") == null ? 0 : app.getProperty("lowAlt")).toNumber();        
        var topAlt = (app.getProperty("topAlt") == null ? 0 : app.getProperty("topAlt")).toNumber();
        
        dc.setPenWidth(3);
        dc.setColor(App.getApp().getProperty("HandsBottomColor"), Gfx.COLOR_TRANSPARENT);
        dc.drawText(xPos, dc.getHeight() - 60, Gfx.FONT_XTINY, lowAlt.toString(), Gfx.TEXT_JUSTIFY_RIGHT);
        dc.drawText(xPos, 40, Gfx.FONT_XTINY, topAlt.toString(), Gfx.TEXT_JUSTIFY_RIGHT);
        dc.setColor(themeColor, Gfx.COLOR_TRANSPARENT);
        
        if ((lowAlt.toNumber() < alt) && (topAlt.toNumber() > alt))  {
            var degreeOnScalePerMeter = (90.toFloat() / (topAlt - lowAlt)).toFloat();
            var end = (alt - lowAlt) * degreeOnScalePerMeter;
            var endAngle = 315 + end;
            dc.drawArc(halfWidth, halfWidth, scaleMeterRadius, Gfx.ARC_COUNTER_CLOCKWISE, 315, endAngle);
            
            var angleDeg = ((45 - end) * Math.PI) / 180;
            var pointX1 = ((scaleStartCircle * Math.cos(angleDeg)) + halfWidth);
            var pointY1 = ((scaleStartCircle * Math.sin(angleDeg)) + halfWidth);       
            var pointX2 = ((scaleEndCircle * Math.cos(angleDeg)) + halfWidth);
            var pointY2 = ((scaleEndCircle * Math.sin(angleDeg)) + halfWidth);  
            dc.drawLine(pointX1, pointY1, pointX2, pointY2);        
            
            angleDeg = ((45 - end - 4) * Math.PI) / 180;
            pointX1 = ((scaleStartCircle * Math.cos(angleDeg)) + halfWidth);
            pointY1 = ((scaleStartCircle * Math.sin(angleDeg)) + halfWidth);       
            pointX2 = ((scaleEndCircle * Math.cos(angleDeg)) + halfWidth);
            pointY2 = ((scaleEndCircle * Math.sin(angleDeg)) + halfWidth);  
            dc.drawLine(pointX1, pointY1, pointX2, pointY2);        
        } else {
            recalculateAltScale(alt);
            drawAltToMeter(dc);
        }     
    }
    
    
    function recalculateAltScale(alt) {
        var lowAlt = 0;
        var topAlt = 0;
                     
        if ((alt < 100) && (alt > -100)) {  // if is altitude between 100 and -100 is necessary to 
            lowAlt = (alt / 100).format("%.2f").toDouble() * 50;    // to calculate with
            topAlt = (alt / 100).format("%.2f").toDouble() * 150;   // decimals
        } else {                                                    // otherwise it will be rounded 
            lowAlt = (alt / 100).format("%.0f").toDouble() * 50;    // to 
            topAlt = (alt / 100).format("%.0f").toDouble() * 150;   // hundreds
        }
                                  
        if (alt < 0) {
            app.setProperty("lowAlt", topAlt);
            app.setProperty("topAlt", lowAlt);
        } else {
            app.setProperty("lowAlt", lowAlt);
            app.setProperty("topAlt", topAlt);
        }
        
    }
}
