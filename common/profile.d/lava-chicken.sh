# Put the shared LaCOS tools (newt, lacos, nugget) on PATH for every user, so the
# per-user "nugget" agent works for admins and kids alike. Installed to
# /etc/profile.d/lava-chicken.sh.
case ":$PATH:" in
  *:/var/lib/lava-chicken/bin:*) ;;
  *) PATH="/var/lib/lava-chicken/bin:$PATH" ;;
esac
export PATH
