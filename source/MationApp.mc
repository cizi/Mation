using Toybox.Application;
using Toybox.WatchUi;

class MationApp extends Application.AppBase {

    var weatherForecast = null;

    const WEATHER = 14;

    function initialize() {
        AppBase.initialize();
    }

    // onStart() is called on application start up
    function onStart(state) {
    }

    // onStop() is called when your application is exiting
    function onStop(state) {
    }

    // Return the initial view of your application here
    function getInitialView() {
        return [ new MationView() ];
    }

    // New app settings have been received so trigger a UI update
    function onSettingsChanged() {
        var app = Application.getApp();
        // Weather
        if (app.getProperty("Opt1") == app.WEATHER) {
            weatherForecast = new WeatherForecast();
        } else {
            weatherForecast = null;
        }
        WatchUi.requestUpdate();
    }

}