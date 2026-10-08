// Preloaded into the functions emulator by scripts/emulator/start.sh (NODE_OPTIONS).
//
// The emulator wraps firebase-admin and hands out `admin.firestore` (and the
// other service namespaces) through Function.prototype.bind unless the value
// looks like a constructor. firebase-admin's namespaces are plain functions
// with no prototype, so the bound copy loses their static members and
// `admin.firestore.FieldValue.serverTimestamp()` throws locally while working
// in production. Giving each namespace function a prototype makes the emulator
// return it unbound. Seen in firebase-tools 15.13.0 and 15.32.1
// (functionsEmulatorRuntime.js, Proxied.getOriginal).
"use strict";

const Module = require("module");

const NAMESPACES = ["firestore", "auth", "database", "storage", "messaging"];
const patched = new WeakSet();

function patchAdmin(admin) {
  if (!admin || typeof admin !== "object" || patched.has(admin)) return;
  patched.add(admin);
  const proto = Object.getPrototypeOf(admin);
  for (const name of NAMESPACES) {
    const descriptor = proto && Object.getOwnPropertyDescriptor(proto, name);
    if (!descriptor || typeof descriptor.get !== "function") continue;
    Object.defineProperty(admin, name, {
      configurable: true,
      get() {
        const namespace = descriptor.get.call(admin);
        if (typeof namespace === "function" && !namespace.prototype) {
          Object.defineProperty(namespace, "prototype", { value: { constructor: namespace } });
        }
        return namespace;
      },
    });
  }
}

const originalLoad = Module._load;
Module._load = function (request, parent, isMain) {
  const loaded = originalLoad.apply(this, arguments);
  if (request === "firebase-admin" || /[\\/]firebase-admin[\\/]lib[\\/]index\.js$/.test(request)) {
    patchAdmin(loaded);
  }
  return loaded;
};
