# Copyright (C) 2026 Bart Bunting
# SPDX-License-Identifier: GPL-2.0-or-later
#
# This file is not part of GNU Emacs, but the same permissions apply.
# See the file COPYING in this distribution.

# Shared persistent line protocol for native Windows speech bridges.

proc windows_speech_source_tts_library {server_directory} {
    global env
    set candidates [list [file join $server_directory tts-lib.tcl]]
    if {[info exists env(EMACSPEAK_DIR)] &&
        $env(EMACSPEAK_DIR) ne ""} {
        lappend candidates \
            [file join $env(EMACSPEAK_DIR) servers tts-lib.tcl]
    }
    foreach candidate $candidates {
        if {[file isfile $candidate]} {
            uplevel #0 [list source $candidate]
            return [file normalize $candidate]
        }
    }
    error "Emacspeak tts-lib.tcl not found; set EMACSPEAK_DIR to the Emacspeak root"
}

proc windows_speech_export_to_windows {name} {
    global env
    set entries {}
    if {[info exists env(WSLENV)] && $env(WSLENV) ne ""} {
        foreach entry [split $env(WSLENV) :] {
            if {[lindex [split $entry /] 0] ne $name} {
                lappend entries $entry
            }
        }
    }
    lappend entries "$name/w"
    set env(WSLENV) [join $entries :]
}

proc windows_speech_start {state_name description program arguments} {
    global env
    upvar #0 $state_name state
    if {[info exists env(EMACSPEAK_WINDOWS_SPEECH_PAN)] &&
        $env(EMACSPEAK_WINDOWS_SPEECH_PAN) ne ""} {
        windows_speech_export_to_windows EMACSPEAK_WINDOWS_SPEECH_PAN
    }
    set command [list | $program]
    foreach argument $arguments {
        lappend command $argument
    }
    set state(description) $description
    set state(channel) [open $command r+]
    fconfigure $state(channel) \
        -blocking 1 -buffering line -encoding ascii -translation crlf
}

proc windows_speech_decode_error {payload description} {
    if {$payload eq ""} {
        return "Unknown $description error"
    }
    return [encoding convertfrom utf-8 [binary decode base64 $payload]]
}

proc windows_speech_rpc {state_name request} {
    upvar #0 $state_name state
    set channel $state(channel)
    puts $channel $request
    flush $channel
    if {[gets $channel response] < 0} {
        error "$state(description) closed unexpectedly"
    }
    if {$response eq "OK"} {
        return ""
    }
    if {[string match "OK *" $response]} {
        return [string range $response 3 end]
    }
    if {[string match "ERR *" $response]} {
        error [windows_speech_decode_error \
                   [string range $response 4 end] $state(description)]
    }
    error "Invalid response from $state(description): $response"
}

proc windows_speech_text_rpc {state_name command text} {
    set bytes [encoding convertto utf-8 $text]
    set payload [binary encode base64 -maxlen 0 $bytes]
    return [windows_speech_rpc $state_name "$command $payload"]
}
