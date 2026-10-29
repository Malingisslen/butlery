"""Upload CI's .aab for a commit to Play's internal track (internal testers only).

Usage: python -I play_upload_internal.py <commit-sha> [release-notes-sv]

Takes a commit, never a file path: only CI writes the production .env
(ENV=production), so a locally built bundle can carry the developer ENV and
stop at startup (versionCode 6, 2026-10-27).
Auth: impersonates play-uploader@butlery-prod via gcloud.

Then starts ios-testflight.yml on main, so TestFlight gets the same code.
A dispatch builds a branch tip, not a commit, so it is started only when
the commit IS origin/main's tip; otherwise the script says so and stops.
"""
import glob, json, os, subprocess, sys, tempfile, urllib.request

PKG = "se.butlery.app"
SA = "play-uploader@butlery-prod.iam.gserviceaccount.com"
REPO = "Malingisslen/butlery"
BASE = f"https://androidpublisher.googleapis.com/androidpublisher/v3/applications/{PKG}"
UPLOAD = f"https://androidpublisher.googleapis.com/upload/androidpublisher/v3/applications/{PKG}"


def sh(args):
    return subprocess.run(args, capture_output=True, text=True, shell=True, check=True).stdout.strip()


def ci_bundle(sha):
    full = sh(["git", "rev-parse", sha])
    runs = json.loads(sh(["gh", "run", "list", "-R", REPO, "--workflow", "build-validation.yml",
                          "--commit", full, "--json", "databaseId,status,conclusion"]))
    done = [r for r in runs if r["status"] == "completed"]
    if not done:
        sys.exit(f"No finished build-validation run for {full}")
    out = tempfile.mkdtemp(prefix="aab-")
    sh(["gh", "run", "download", str(done[0]["databaseId"]), "-R", REPO,
        "-n", f"app-{full}-android.aab", "-D", out])
    found = glob.glob(os.path.join(out, "**", "*.aab"), recursive=True)
    if len(found) != 1:
        sys.exit(f"Expected one .aab in the CI artifact, found {found}")
    return found[0]


def token():
    return sh(["gcloud", "auth", "print-access-token", f"--impersonate-service-account={SA}",
               "--scopes=https://www.googleapis.com/auth/androidpublisher"]).splitlines()[-1]


def call(method, url, tok, body=None, data=None, ctype="application/json"):
    if body is not None:
        data = json.dumps(body).encode()
    req = urllib.request.Request(url, data=data, method=method,
                                 headers={"Authorization": f"Bearer {tok}", "Content-Type": ctype})
    with urllib.request.urlopen(req, timeout=900) as r:
        raw = r.read()
        return json.loads(raw) if raw else {}


def testflight(full):
    sh(["git", "fetch", "-q", "origin", "main"])
    tip = sh(["git", "rev-parse", "origin/main"])
    if tip != full:
        print(f"TestFlight NOT started: origin/main is {tip[:9]}, not {full[:9]}")
        return
    sh(["gh", "workflow", "run", "ios-testflight.yml", "-R", REPO, "--ref", "main",
        "-f", "confirm=UPLOAD"])
    print("TestFlight build started on main (ios-testflight.yml)")


def main():
    aab = ci_bundle(sys.argv[1])
    notes = sys.argv[2] if len(sys.argv) > 2 else None
    tok = token()
    edit = call("POST", f"{BASE}/edits", tok, body={})["id"]
    with open(aab, "rb") as f:
        bundle = call("POST", f"{UPLOAD}/edits/{edit}/bundles?uploadType=media", tok,
                      data=f.read(), ctype="application/octet-stream")
    vc = bundle["versionCode"]
    release = {"versionCodes": [str(vc)], "status": "completed"}
    if notes:
        release["releaseNotes"] = [{"language": "sv-SE", "text": notes}]
    call("PUT", f"{BASE}/edits/{edit}/tracks/internal", tok, body={"track": "internal", "releases": [release]})
    call("POST", f"{BASE}/edits/{edit}:commit", tok)
    print(f"versionCode {vc} committed to internal track")
    testflight(sh(["git", "rev-parse", sys.argv[1]]))


main()
