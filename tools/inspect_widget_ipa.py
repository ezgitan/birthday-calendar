"""Read-only diagnosis for development IPAs. Does not authenticate a code signature."""
import argparse
from fnmatch import fnmatchcase
from pathlib import Path
import plistlib
import struct
import zipfile

GROUP = "group.com.birthdaycalendar.shared"
KEY = "com.apple.security.application-groups"


def claims(binary):
    """Read the XML entitlement slot of an iOS arm64 Mach-O code signature."""
    if binary[:4] == bytes.fromhex("cafebabe"):
        for index in range(struct.unpack_from(">I", binary, 4)[0]):
            cpu, _, start, size, _ = struct.unpack_from(">5I", binary, 8 + 20 * index)
            if cpu == 0x0100000c:
                return claims(binary[start:start + size])
    if binary[:4] != bytes.fromhex("cffaedfe"):
        return "unknown-architecture", {}
    pos = 32
    for _ in range(struct.unpack_from("<I", binary, 16)[0]):
        cmd, size = struct.unpack_from("<II", binary, pos)
        if cmd == 29:  # LC_CODE_SIGNATURE
            start, length = struct.unpack_from("<II", binary, pos + 8)
            blob = binary[start:start + length]
            for slot in range(struct.unpack_from(">I", blob, 8)[0]):
                typ, at = struct.unpack_from(">II", blob, 12 + 8 * slot)
                if typ == 5:
                    length = struct.unpack_from(">I", blob, at + 4)[0]
                    return "present", plistlib.loads(blob[at + 8:at + length])
            return "no-XML-slot (inspect with macOS codesign)", {}
        pos += size
    return "unsigned", {}


def profile_claims(blob):
    # Development profiles are CMS envelopes containing a plist. Inspect the
    # payload only, never print certificates, devices, account IDs or raw data.
    start = blob.find(b"<?xml")
    end = blob.find(b"</plist>", start)
    if start < 0 or end < 0:
        return None
    return plistlib.loads(blob[start:end + 8]).get("Entitlements", {})


def inspect(path):
    teams = []
    with zipfile.ZipFile(path) as ipa:
        root, = [n[:-10] for n in ipa.namelist() if n.startswith("Payload/")
                 and n.count("/") == 2 and n.endswith(".app/Info.plist")]
        for target, bundle in [("Runner", root), ("BirthdayWidget", root + "PlugIns/BirthdayWidget.appex/")]:
            info = plistlib.loads(ipa.read(bundle + "Info.plist"))
            state, ent = claims(ipa.read(bundle + info["CFBundleExecutable"]))
            profile = bundle + "embedded.mobileprovision"
            provision = profile_claims(ipa.read(profile)) if profile in ipa.namelist() else None
            groups = ent.get(KEY, [])
            allowed = provision is not None and any(fnmatchcase(GROUP, item) for item in provision.get(KEY, []))
            team = ent.get("com.apple.developer.team-identifier")
            teams.append(team)
            print(f"{target}: version={info.get('CFBundleShortVersionString')} signature={state} "
                  f"expectedGroupInSignature={GROUP in groups if state == 'present' else 'unknown'} "
                  f"profile={'read' if provision is not None else 'absent/unreadable'} "
                  f"expectedGroupAllowed={allowed if provision is not None else 'unknown'}")
            if target == "BirthdayWidget":
                print("extensionPoint:", info.get("NSExtension", {}).get("NSExtensionPointIdentifier"))
        print("sameSigningTeam:", teams[0] == teams[1] if all(teams) else "unknown")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("ipa", type=Path)
    inspect(parser.parse_args().ipa)
