import QtQuick
import qs.Common

QtObject {
    function check(done) {
        Proc.runCommand("nostrDms.depCheck", ["sh", "-c", "command -v nak"], (stdout, exitCode) => {
            if (exitCode === 0) {
                done(null);
                return;
            }
            done({
                "title": "nak is required",
                "details": "The 'nak' CLI is not installed or not on your PATH.\n\nInstall it:\n\n  curl -sSL https://raw.githubusercontent.com/fiatjaf/nak/master/install.sh | sh\n\nThen re-enable this plugin."
            });
        });
    }
}