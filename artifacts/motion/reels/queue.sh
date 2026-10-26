#!/bin/bash
# Render queue: renders each line of queue.txt in order ("<scene.html> <audio.wav> <out.mp4> [workers]"),
# then waits for more lines until a line "END". Finished lines are recorded in queue.done.
# Optional: WAIT_LOG=<file> WAIT_FOR=<text> ./queue.sh  -> start only once <file> contains <text>
# (e.g. another render's log reporting "done: ...").
cd "$(dirname "$0")"
touch queue.txt queue.done
if [ -n "$WAIT_LOG" ]; then
  while ! grep -q "$WAIT_FOR" "$WAIT_LOG" 2>/dev/null; do sleep 10; done
  echo "[queue] $WAIT_FOR"
fi
while true; do
  line=$(grep -v -x -F -f queue.done queue.txt | head -1)
  if [ -z "$line" ]; then sleep 10; continue; fi
  if [ "$line" = "END" ]; then echo "[queue] all done"; break; fi
  echo "[queue] rendering: $line"
  python3 render.py $line 2>&1 | grep -E "done:|Error|Traceback" || echo "[queue] FAILED: $line"
  echo "$line" >> queue.done
done
