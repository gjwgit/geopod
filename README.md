# GeoPod

A demonstrator app storing data in PODs with a map interface. The
points of interest are shared with a user of the app through secure,
private, encrypted Solid Pods by the custodian of the
knowledge. Within the map interface when a point of interest is tapped
the data/text associated with that point is displayed.

Currently as of 20251121 the app utilises the
[solidui](https://pub.dev/solidui) package to log into a solid server
and to provide the scaffolding for the app. Once logged in you are
presented with a simple map interface. Once Pods are incorporated the
app will retrieve points of interest that you have access to through
your Pod.

![Map Screen Darwin](assets/screenshots/app_login.png)

![Map Screen Darwin](assets/screenshots/map_screen_darwin.png)
