The executables are for Windows!

You have two ways of using this:
1. Use the executables from the Releases.
2. Grab the Godot projects from the folders and compile the executables yourself.
   Godot 4.3 was used for the creation of both the server and the client executables for Releases.

Once you have the executables:
- Both players must have a client executable.
- One player must have a server executable.
- One must hit "host" on the server to start it.
- After creating a server password, give it to your friend.
- Also give your friend the server IP (This is going to be your IP if you're hosting locally) and the port (typically 31400).
  PSA: Don't give people you don't trust your IP. It can lead to your general location being leaked and/or DDoS attacks.

In the client: The first password is for your user while the second password is the server password.
You set the user password when you're first going into the game. Your user information resets everytime the server resets.

If the server executable isn't giving positive feedback and the clients aren't connecting, you might need to set some things up.
If you've ever set up a Minecraft server, it's kind of like that!
You must go into your router settings and set up port forwarding (there are YouTube tutorials you can find if you're struggling).

If it still doesn't work, you'll need to setup Ingoing and Outgoing firewall rules for UTP and TCP. That's four rules in total.

If things still don't work, there's likely a virus defender or something of that sort clocking the signals as malicious.

---------- CREDITS ----------
- Sounds: https://github.com/lichess-org/lila/tree/master/public/sound/standard
- All Else: Me
