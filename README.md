# AllStar-Time-Weather

**Hourly time, weather, and NWS watch/warning announcements for AllStarLink ASL3 nodes.**

Created by **KJ5MLL / Brian** — Southern States Reflector

---

## What It Does

At the top of every hour, your AllStar node will announce:

- Good morning / Good afternoon / Good evening
- The current time with AM/PM
- Current temperature in Fahrenheit
- Current weather conditions
- **National Weather Service active watches and warnings for your area** *(new in v2.0)*

All audio uses the existing sound files already installed with ASL3 — no additional audio downloads required. NWS alerts use no API key and require no account.

---

## Requirements

- AllStarLink ASL3 installed and working
- A free account at [WeatherAPI.com](https://www.weatherapi.com) (free tier supports up to 1 million calls/month)
- `curl` and `python3` (already installed on most ASL3 systems)
- Your latitude and longitude (find yours at [latlong.net](https://www.latlong.net))

---

## Installation

**Step 1 — Get a free WeatherAPI.com API key:**

Go to https://www.weatherapi.com, create a free account, and copy your API key from the dashboard.

**Step 2 — Find your latitude and longitude:**

Go to https://www.latlong.net, search for your city, and copy the decimal coordinates (e.g. 34.2740, -88.4092).

**Step 3 — Download and run the installer:**

```
wget https://raw.githubusercontent.com/briankj5mll/AllStar-Time-Weather-Watch-Warning-Alerts-NWS/main/install_time_weather.sh
chmod +x install_time_weather.sh
sudo bash install_time_weather.sh
```

**Step 4 — Answer the prompts:**

```
Enter your AllStar node number: 12345
Enter your WeatherAPI.com API key: your_key_here
Enter your ZIP code: 38843
Enter your latitude (e.g. 34.2740): 34.2740
Enter your longitude (e.g. -88.4092): -88.4092
```

That's it. The installer will:

- Write `/usr/local/sbin/get_weather.sh`
- Write `/usr/local/sbin/saytime_wx.sh`
- Set up the cron job to run at the top of every hour
- Test the weather API connection

---

## NWS Watch/Warning Alerts

Version 2.0 adds automatic NWS alert checking using [api.weather.gov](https://api.weather.gov) — no API key or account required.

After the regular time and weather announcement, the script checks for active watches and warnings in your area. If an alert is found it plays immediately using existing ASL3 sound files. Advisories and minor statements are filtered out — only significant events like tornado warnings, severe thunderstorm warnings, and similar alerts are announced.

---

## Testing

To test manually at any time:

```
sudo /usr/local/sbin/saytime_wx.sh
```

You should hear the announcement immediately on your node.

To view the log:

```
tail -f /var/log/time_weather.log
```

To verify the cron job is set:

```
sudo crontab -l
```

---

## Uninstall

```
sudo crontab -l | grep -v saytime_wx | sudo crontab -
sudo rm -f /usr/local/sbin/saytime_wx.sh /usr/local/sbin/get_weather.sh
sudo rm -f /var/log/time_weather.log
```

---

## Files

| File | Description |
|---|---|
| `install_time_weather.sh` | Installer — run this once to set everything up |

The installer creates:

| File | Description |
|---|---|
| `/usr/local/sbin/get_weather.sh` | Fetches current weather from WeatherAPI.com |
| `/usr/local/sbin/saytime_wx.sh` | Builds and plays the announcement on your node |
| `/var/log/time_weather.log` | Log file for troubleshooting |

---

## Troubleshooting

**Only hearing the time, no weather:**

```
sudo /usr/local/sbin/get_weather.sh
```

Should return something like `82|partly cloudy`. If it returns nothing, check your API key and internet connection.

**NWS alerts not working:**

```
curl "https://api.weather.gov/alerts/active?point=YOUR_LAT,YOUR_LON" -H "Accept: application/geo+json"
```

Should return a JSON response. If it fails check your internet connection and verify your lat/lon coordinates are correct.

**Announcement not playing at the top of the hour:**

```
sudo crontab -l
tail -20 /var/log/time_weather.log
```

---

## Changelog

**v2.0**
- Added NWS watch/warning alert announcements using api.weather.gov (no API key required)
- Added latitude/longitude prompt to installer
- Advisories and minor statements filtered — only significant alerts announced

**v1.0**
- Initial release — hourly time and weather announcements

---

## License

Free to use and modify. Credit appreciated. 73 de KJ5MLL
