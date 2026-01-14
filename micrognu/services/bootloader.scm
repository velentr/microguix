;;; SPDX-FileCopyrightText: 2026 Brian Kubisiak <brian@kubisiak.com>
;;;
;;; SPDX-License-Identifier: GPL-3.0-or-later

(define-module (micrognu services bootloader)
  #:use-module (gnu services)
  #:use-module (gnu services configuration)
  #:use-module (guix gexp)
  #:use-module (guix records)
  #:use-module (ice-9 match)
  #:export (u-boot-env-configuration
            u-boot-env-configuration?
            u-boot-env-service-type))

(define-configuration/no-serialization u-boot-env-configuration
  (device string "Path to the block device holding the u-boot env.")
  (offset (number 0) "Offset of the env in bytes.")
  (size number "Size of the env in bytes.")
  (sector-size number "Sector size for the flash device.")
  (number-of-sectors number "Number of flash sectors containing the env."))

(define (u-boot-env-service-etc config)
  `(("fw_env.config"
     ,(apply
       mixed-text-file
       "fw_env.config"
       (map
        (match-lambda
          (( $ <u-boot-env-configuration>
             device offset size sector-size number-of-sectors)
           (format #f "~a 0x~x 0x~x 0x~x ~d~%"
                   device offset size sector-size number-of-sectors)))
        config)))))

(define u-boot-env-service-type
  (service-type
   (name 'u-boot-env)
   (extensions
    (list (service-extension etc-service-type u-boot-env-service-etc)))
   (description "Configure the u-boot environment storage location.")
   (default-value '())))
