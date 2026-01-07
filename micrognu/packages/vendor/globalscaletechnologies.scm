;;; SPDX-FileCopyrightText: 2024 Brian Kubisiak <brian@kubisiak.com>
;;;
;;; SPDX-License-Identifier: GPL-3.0-or-later

(define-module (micrognu packages vendor globalscaletechnologies)
  #:use-module (gnu packages linux)
  #:use-module (guix gexp)
  #:use-module (guix git-download)
  #:use-module (guix packages)
  #:use-module (micrognu packages linux))

(define-public linux-espressobin-ultra-5.4
  (package
    (inherit
     (customize-linux
      #:name "linux-espressobin-ultra"
      #:source (origin
                 (method git-fetch)
                 (uri (git-reference
                       (url "https://github.com/globalscaletechnologies/linux.git")
                       (commit "linux-5.4.53-gti")))
                 (file-name (git-file-name "linux-espressobin-ultra" "5.4.53-gti"))
                 (sha256
                  (base32 "1pwpn6wrz6ydx62gp9g2drapg126lwihcr0yhhcqilc1cxy7m02q")))
      #:defconfig (local-file "gti_ccpe-88f3720_defconfig")
      #:extra-version "guix"))
    (version "5.4.53-gti")
    (home-page "https://github.com/globalscaletechnologies/linux")
    (synopsis "Linux kernel with patches from globalscale technologies")
    (description "Linux kernel build from globalscale technologies sources,
including nonfree binary blobs.")))

(define-public espressobin-ultra-linux-firmware
  (package/linux-firmware
   "^mrvl/pcieusb8997_combo_v4"
   (name "espressobin-ultra-linux-firmware")
   (license
    ((@@ (guix licenses) license)
     "Nonfree"
     "https://gitlab.com/kernel-firmware/linux-firmware/-/blob/main/LICENCE.Marvell"
     ""))))
