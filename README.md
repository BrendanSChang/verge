# verge
Intelligent schedule management (MIT 6.S062 SP2015 Final Project)

Verge attempts time of arrival estimations for pedestrian commutes. It
uses GPS for outdoor localization and magnetic heading with step counting
for indoor localization. Localization is used to estimate user velocity,
which is then projected in the direction from the user's current position
to the intended destination to calculate the user's ETA.


# Future Work

Most of the work on Verge has been on localization and the ETA mechanisms.
Eventually, we would like for Verge to connect to a user's schedule (e.g.
via Google Calendar) and be able to estimate whether a user is on-time for
her scheduled appointments.


## TODO

1. Keep a longer list of previous locations/velocities to average.
2. Tune parameters. 
3. Test the application along an indoor/outdoor path. 
4. Test accuracy of magnetic heading indoors.
