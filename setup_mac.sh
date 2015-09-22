# Mac OSX related fixes

# Show User's library folder all the time
chflags nohidden ~/Library/

# Link Sublime executable to bin directory for temrinal access
ln -s /Applications/Sublime\ Text.app/Contents/SharedSupport/bin/subl /usr/local/bin/subl  # Sublime 3
