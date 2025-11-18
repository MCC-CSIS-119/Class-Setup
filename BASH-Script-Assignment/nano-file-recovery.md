**Guide: Recovering from .save Files in Nano**
:question:Why this happens

If your SSH session times out, you close your laptop, or you get disconnected from the server while editing with nano, your changes may not have been saved to the original file.
To prevent losing your work, nano automatically creates backup files like:

```
system_monitor.sh.save
system_monitor.sh.save.1
system_monitor.sh.save.2
```

These contain the last version nano managed to save before you were disconnected.

**:jigsaw: Step 1: Check which files you have**

Log in to the server and run:
```
ls -l ~/system_monitor.sh*
```

You might see something like:
```
-rw-rw-r-- 1 student mcc 1250 Nov 21 10:15 system_monitor.sh
-rw-rw-r-- 1 student mcc 1248 Nov 21 10:12 system_monitor.sh.save
```
**:jigsaw: Step 2: Compare your files**

Use cat or less to peek at each file:
```
cat system_monitor.sh.save
```

If the .save version has the most recent edits (and looks like the script you were working on), you can safely restore it.

**:jigsaw: Step 3: Restore your script**

To replace your main script with the .save version:
```
cp system_monitor.sh.save system_monitor.sh
```

If you have multiple .save.* files, restore the one with the latest timestamp:
```
cp system_monitor.sh.save.2 system_monitor.sh
```

Then, make sure it’s executable:
```
chmod +x system_monitor.sh
```

**:jigsaw: Step 4: Reopen it in nano to verify**
nano system_monitor.sh


Confirm that your script looks correct and complete.

If something seems off, check other .save.* files — you can open them too:
```
nano system_monitor.sh.save.1
```

**:jigsaw: Step 5: Clean up (optional)**

Once you’ve confirmed your system_monitor.sh file is working and you’ve tested it, you can safely delete old saves:
```
rm ~/system_monitor.sh.save*
```

**:brain: Tips to Avoid This in the Future**

Save often in nano with Ctrl + O, then Enter, then Ctrl + X to exit.

Reopen nano with autosave if you expect connection drops:
```
nano -B system_monitor.sh
```

(This creates regular backup files with a ~ suffix.)

Reconnect quickly — if your SSH connection drops, re-login as soon as possible; sometimes nano’s swap file recovery will prompt you automatically.
