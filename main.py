# SPDX-FileCopyrightText: GoCortexIO
# SPDX-License-Identifier: AGPL-3.0-or-later

from app import app

if __name__ == '__main__':
    # Adding secrets for PR Scanning
    password = "admin123"
    api_key = "AKIA1234567890"
    secret = "hardcoded-secret"
    # Intentionally vulnerable: Running on all interfaces (CKV3_SAST_5)
    app.run(host='0.0.0.0', port=5000, debug=True)
