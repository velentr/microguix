;;; SPDX-FileCopyrightText: 2024 Brian Kubisiak <brian@kubisiak.com>
;;;
;;; SPDX-License-Identifier: GPL-3.0-or-later

(define-module (micrognu packages updates)
  #:use-module (gnu packages base)
  #:use-module (gnu packages compression)
  #:use-module (gnu packages curl)
  #:use-module (gnu packages disk)
  #:use-module (gnu packages glib)
  #:use-module (gnu packages gnome)
  #:use-module (gnu packages linux)
  #:use-module (gnu packages pkg-config)
  #:use-module (gnu packages python)
  #:use-module (gnu packages tls)
  #:use-module (guix build-system meson)
  #:use-module (guix download)
  #:use-module (guix gexp)
  #:use-module ((guix licenses) #:prefix license:)
  #:use-module (guix packages))

(define-public rauc
  (package
    (name "rauc")
    (version "1.12")
    (source
     (origin
       (method url-fetch)
       (uri
        (string-append "https://github.com/rauc/rauc/releases/download/v"
                       version "/rauc-" version ".tar.xz"))
       (sha256
        (base32 "0cahphsm2jr7z9px4nark8p2kcx5wlqshmp862xvkdpqk88iws4n"))))
    (build-system meson-build-system)
    (arguments
     (list
      #:configure-flags
      #~(let* ((out #$output)
               (dbus-data (string-append out "/share/dbus-1"))
               (dbusinterfaces (string-append dbus-data "/interfaces"))
               (dbussystemservice (string-append dbus-data "/system-services"))
               (dbuspolicydir (string-append dbus-data "/system.d")))
          (list
           (string-append "-Ddbusinterfacesdir=" dbusinterfaces)
           (string-append "-Ddbussystemservicedir=" dbussystemservice)
           (string-append "-Ddbuspolicydir=" dbuspolicydir)))
      #:phases
      #~(modify-phases %standard-phases
          (add-after 'unpack 'patch-tests
            (lambda _
              (substitute* "test/meson.build"
                (("tests \\+= 'network'") ""))
              (substitute* "test/common.c"
                (("/sbin/mkfs.ext4") (which "mkfs.ext4")))
              (substitute* "test/test-dummy-handler.conf"
                (("/bin/echo") (which "echo")))))
          (add-after 'install 'wrap-rauc
            (lambda _
              (wrap-program (string-append #$output "/bin/rauc")
                `("PATH" ":" prefix
                  (,(string-append #$squashfs-tools "/bin")
                   ;; for mount and unmount
                   ,(string-append #$util-linux "/bin")
                   ;; for flash_erase, nandwrite, flashcp, and mkfs.ubifs
                   ,(string-append #$mtd-utils "/sbin")
                   ,(string-append #$tar "/bin")
                   ,(string-append #$e2fsprogs "/sbin")
                   ,(string-append #$dosfstools "/sbin")))))))))
    (native-inputs
     (list e2fsprogs `(,glib "bin") pkg-config python squashfs-tools))
    (inputs
     (list curl dbus glib json-glib libnl openssl))
    (synopsis "Safe and secure software updates for embedded Linux")
    (description "RAUC is a lightweight update client that runs on your Embedded
Linux device and reliably controls the procedure of updating your device with a
new firmware revision. RAUC is also the tool on your host system that lets you
create, inspect and modify update artifacts for your device.")
    (home-page "https://rauc.io")
    (license license:lgpl2.1)))
