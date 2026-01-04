;;; SPDX-FileCopyrightText: 2025 Brian Kubisiak <brian@kubisiak.com>
;;; SPDX-FileCopyrightText: 2019, 2020 Alex Griffin <a@ajgrf.com>
;;; SPDX-FileCopyrightText: 2019 Pierre Neidhardt <mail@ambrevar.xyz>
;;; SPDX-FileCopyrightText: 2019 Giacomo Leidi <goodoldpaul@autistici.org>
;;; SPDX-FileCopyrightText: 2019 Timotej Lazar <timotej.lazar@araneo.si>
;;; SPDX-FileCopyrightText: 2020, 2021 James Smith <jsubuntuxp@disroot.org>
;;; SPDX-FileCopyrightText: 2020-2025 Jonathan Brielmaier <jonathan.brielmaier@web.de>
;;; SPDX-FileCopyrightText: 2020, 2022 Michael Rohleder <mike@rohleder.de>
;;; SPDX-FileCopyrightText: 2020, 2021, 2022 Tobias Geerinckx-Rice <me@tobias.gr>
;;; SPDX-FileCopyrightText: 2020-2023, 2025 Zhu Zihao <all_but_last@163.com>
;;; SPDX-FileCopyrightText: 2021 Mathieu Othacehe <m.othacehe@gmail.com>
;;; SPDX-FileCopyrightText: 2021 Brice Waegeneire <brice@waegenei.re>
;;; SPDX-FileCopyrightText: 2021 Risto Stevcev <me@risto.codes>
;;; SPDX-FileCopyrightText: 2021 aerique <aerique@xs4all.nl>
;;; SPDX-FileCopyrightText: 2022 Josselin Poiret <dev@jpoiret.xyz>
;;; SPDX-FileCopyrightText: 2022, 2023, 2024, 2025 John Kehayias <john.kehayias@protonmail.com>
;;; SPDX-FileCopyrightText: 2022 Petr Hodina <phodina@protonmail.com>
;;; SPDX-FileCopyrightText: 2022 Remco van 't Veer <remco@remworks.net>
;;; SPDX-FileCopyrightText: 2022 Simen Endsjø <simendsjo@gmail.com>
;;; SPDX-FileCopyrightText: 2022 Leo Famulari <leo@famulari.name>
;;; SPDX-FileCopyrightText: 2023 Krzysztof Baranowski <pharcosyle@gmail.com>
;;; SPDX-FileCopyrightText: 2023 Morgan Smith <Morgan.J.Smith@outlook.com>
;;; SPDX-FileCopyrightText: 2023 Jelle Licht <jlicht@fsfe.org>
;;; SPDX-FileCopyrightText: 2023 Adam Kandur <rndd@tuta.io>
;;; SPDX-FileCopyrightText: 2023 Hilton Chain <hako@ultrarare.space>
;;; SPDX-FileCopyrightText: 2023, 2024, 2025 Ada Stevenson <adanskana@gmail.com>
;;; SPDX-FileCopyrightText: 2023 Tomas Volf <~@wolfsden.cz>
;;; SPDX-FileCopyrightText: 2023 PRESFIL <presfil@protonmail.com>
;;; SPDX-FileCopyrightText: 2024, 2025 Maxim Cournoyer <maxim.cournoyer@gmail.com>
;;; SPDX-FileCopyrightText: 2025 David Wilson <david@systemcrafters.net>
;;; SPDX-FileCopyrightText: 2025 Murilo <murilo@disroot.org>
;;;
;;; SPDX-License-Identifier: GPL-3.0-or-later

(define-module (micrognu packages linux)
  #:use-module (guix build-system gnu)
  #:use-module (guix download)
  #:use-module (guix gexp)
  #:use-module (guix licenses)
  #:use-module (guix packages)
  #:use-module (guix utils)
  #:export (package/linux-firmware))

(define linux-firmware-complete
  (package
    (name "linux-firmware-complete")
    (version "20251125")
    (source (origin
              (method url-fetch)
              (uri (string-append "mirror://kernel.org/linux/kernel/firmware/"
                                  "linux-firmware-" version ".tar.xz"))
              (sha256
               (base32
                "1liwx6ga14sz5bb8f4mccmhrw83b4i58srsvxybsr0i8ql0pm07b"))))
    (build-system gnu-build-system)
    (arguments
     (list #:tests? #f
           #:strip-binaries? #f
           #:validate-runpath? #f
           #:make-flags #~(list (string-append "DESTDIR=" #$output))
           #:phases
           #~(modify-phases %standard-phases
               (add-after 'unpack 'patch-out-check_whence.py
                 (lambda _
                   ;; The 'check_whence.py' script requires git (and the
                   ;; repository metadata).
                   (substitute* "copy-firmware.sh"
                     (("./check_whence.py")
                      "true"))))
               (delete 'configure))))
    (home-page
     "https://git.kernel.org/pub/scm/linux/kernel/git/firmware/linux-firmware.git")
    (synopsis "Nonfree firmware blobs for Linux")
    (description "Nonfree firmware blobs for enabling support for various
hardware in the Linux kernel.  This is a large package which may be overkill
if your hardware is supported by one of the smaller firmware packages.")
    (license
     ((@@ (guix licenses) license)
      "Nonfree"
      "https://gitlab.com/kernel-firmware/linux-firmware/-/blob/main/LICENSE"
      "Individual firmware binaries are released under licenses described in
`WHENCE`."))))

(define (select-firmware keep)
  "Modify linux-firmware copy list to retain only files matching KEEP regex."
  #~(lambda _
      (use-modules (ice-9 regex))
      (substitute* "WHENCE"
        (("^(File|RawFile): *([^ ]*)(.*)" _ type file rest)
         (string-append (if (string-match #$keep file) type "Skip") ": " file rest))
        (("^Link: *(.*) *-> *(.*)" _ file target)
         (string-append (if (string-match #$keep target) "Link" "Skip")
                        ": " file " -> " target)))))

(define-syntax-rule (package/linux-firmware regex args ...)
  (package/inherit linux-firmware-complete
    args
    ...
    (arguments
     (cons*
      ;; we don't actually want to install a license file on the device
      #:license-file-regexp "invalid-license-regexp"
      (substitute-keyword-arguments (package-arguments linux-firmware-complete)
        ((#:phases phases #~%standard-phases)
         #~(modify-phases #$phases
             (add-after 'unpack 'select-firmware
               #$(select-firmware regex)))))))))
