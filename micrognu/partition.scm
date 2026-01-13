;;; SPDX-FileCopyrightText: 2026 Brian Kubisiak <brian@kubisiak.com>
;;; SPDX-FileCopyrightText: 2020, 2021, 2022 Mathieu Othacehe <othacehe@gnu.org>
;;; SPDX-FileCopyrightText: 2020 Jan (janneke) Nieuwenhuizen <janneke@gnu.org>
;;; SPDX-FileCopyrightText: 2022 Pavel Shlyak <p.shlyak@pantherx.org>
;;; SPDX-FileCopyrightText: 2022 Denis 'GNUtoo' Carikli <GNUtoo@cyberdimension.org>
;;; SPDX-FileCopyrightText: 2022 Alex Griffin <a@ajgrf.com>
;;; SPDX-FileCopyrightText: 2023, 2025 Efraim Flashner <efraim@flashner.co.il>
;;; SPDX-FileCopyrightText: 2023 Oleg Pykhalov <go.wigust@gmail.com>
;;;
;;; SPDX-License-Identifier: GPL-3.0-or-later

(define-module (micrognu partition)
  #:use-module (ice-9 match)
  #:use-module ((srfi srfi-1) #:prefix srfi-1:)
  #:use-module (gnu bootloader)
  #:use-module (gnu image)
  #:use-module (gnu packages base)
  #:use-module (gnu packages gnupg)
  #:use-module (gnu packages guile)
  #:use-module (gnu packages linux)
  #:use-module (gnu system)
  #:use-module (gnu system uuid)
  #:use-module (guix gexp)
  #:use-module (guix modules)
  #:use-module (guix packages)
  #:use-module ((guix self) #:select (make-config.scm))
  #:use-module (guix utils)
  #:export (rootfs-partition))

(define not-config?
  ;; Select (guix …) and (gnu …) modules, except (guix config).
  (match-lambda
    (('guix 'config) #f)
    (('guix rest ...) #t)
    (('gnu rest ...) #t)
    (rest #f)))

(define (partition->gexp partition)
  "Turn PARTITION, a <partition> object, into a list-valued gexp suitable for
'make-partition-image'."
  #~'(#$@(list (partition-size partition))
      #$(partition-file-system partition)
      #$(partition-file-system-options partition)
      #$(partition-label partition)
      #$(and=> (partition-uuid partition)
               uuid-bytevector)
      #$(partition-flags partition)))

(define gcrypt-sqlite3&co
  ;; Guile-Gcrypt, Guile-SQLite3, and their propagated inputs.
  (srfi-1:append-map
   (lambda (package)
     (cons package
           (match (package-transitive-propagated-inputs package)
             (((labels packages) ...)
              packages))))
   (list guile-gcrypt guile-sqlite3)))

(define-syntax-rule (with-imported-modules* gexp* ...)
  (with-extensions gcrypt-sqlite3&co
    (with-imported-modules `(,@(source-module-closure
                                '((gnu build image)
                                  (gnu build bootloader)
                                  (gnu build hurd-boot)
                                  (gnu build linux-boot)
                                  (guix store database))
                                #:select? not-config?)
                             ((guix config) => ,(make-config.scm)))
      #~(begin
          (use-modules (gnu build image)
                       (gnu build bootloader)
                       (gnu build hurd-boot)
                       (gnu build linux-boot)
                       (guix store database)
                       (guix build utils))
          gexp* ...))))

(define* (rootfs-partition #:key partition os target)
  ;; Return as a file-like object, an image of the given PARTITION.  A
  ;; directory, filled by calling the PARTITION initializer procedure, is
  ;; first created within the store.  Then, an image of this directory is
  ;; created using tools such as 'mke2fs' or 'mkdosfs', depending on the
  ;; partition file-system type.
  (with-parameters ((%current-target-system target))
    (let* ((schema (local-file (search-path %load-path
                                            "guix/store/schema.sql")))
           (bootcfg (operating-system-bootcfg os))
           (bootloader (bootloader-configuration-bootloader
                        (operating-system-bootloader os)))
           (inputs `(("system" ,os)
                     ("bootcfg" ,bootcfg)))
           (graph (match inputs
                    (((names . _) ...)
                     names)))
           (type (partition-file-system partition))
           (image-builder
            (with-imported-modules*
             (let ((initializer (or #$(partition-initializer partition)
                                    initialize-root-partition))
                   (inputs '#+(cond
                               ((string=? type "btrfs")
                                (list btrfs-progs fakeroot))
                               ((string-prefix? "ext" type)
                                (list e2fsprogs fakeroot))
                               ((string=? type "f2fs")
                                (list f2fs-tools fakeroot))
                               ((string=? type "swap")
                                (list fakeroot util-linux))
                               ((or (string=? type "vfat")
                                    (string-prefix? "fat" type))
                                (list dosfstools fakeroot mtools))
                               (else
                                '())))
                   (image-root "tmp-root"))
               (sql-schema #$schema)

               (set-path-environment-variable "PATH" '("bin" "sbin") inputs)

               ;; Allow non-ASCII file names--e.g., 'nss-certs'--to be
               ;; decoded.
               (setenv "GUIX_LOCPATH"
                       #+(file-append (libc-utf8-locales-for-target
                                       (%current-system))
                                      "/lib/locale"))
               (setlocale LC_ALL "en_US.utf8")

               (initializer image-root
                            #:references-graphs '#$graph
                            #:deduplicate? #f
                            #:copy-closures? #t
                            #:system-directory #$os
                            #:bootloader-package
                            #+(bootloader-package bootloader)
                            #:bootloader-installer
                            #+(bootloader-installer bootloader)
                            #:bootcfg #$bootcfg
                            #:bootcfg-location
                            #$(bootloader-configuration-file bootloader))
               (make-partition-image #$(partition->gexp partition)
                                     #$output
                                     image-root)))))
      (computed-file "partition.img" image-builder
                     ;; Allow offloading so that this I/O-intensive process
                     ;; doesn't run on the build farm's head node.
                     #:local-build? #f
                     #:options `(#:references-graphs ,inputs)))))
