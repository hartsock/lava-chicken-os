# Put the shared LaCOS tools (newt, lacos, nugget) on PATH for every user, so the
# per-user "nugget" agent works for admins and kids alike. Installed to
# /etc/profile.d/lava-chicken.sh.
case ":$PATH:" in
  *:/var/lib/lava-chicken/bin:*) ;;
  *) PATH="/var/lib/lava-chicken/bin:$PATH" ;;
esac
export PATH

# Nudge admins to finish the 2nd-boot wizard until it's done.
if [ -t 1 ] && [ ! -e /etc/lava-chicken/setup.done ] && id -nG 2>/dev/null | tr ' ' '\n' | grep -qx wheel; then
  printf '\n  \033[1;33mLaCOS:\033[0m finish setup with  \033[1mlacos setup\033[0m  (Tailscale, home DNS, ...)\n\n'
fi
