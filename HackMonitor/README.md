# HackMonitor — iPad Air 1 / iOS 12

Aplicación nativa UIKit para iPad Air de primera generación (iOS 12).
Lee por Wi-Fi las estadísticas de un Hackintosh macOS Sonoma Intel.

## Compilación automática

La rama \`hackmonitor-ipad-ios12\` contiene
\`.github/workflows/build-hackmonitor.yml\`. En **Actions** abre el run
**Build HackMonitor iOS 12** y descarga el artifact
**HackMonitor-iOS12-unsigned** (contiene el IPA).

El IPA se genera **sin firmar**, por seguridad: para instalarlo en un
iPad normal sin jailbreak necesitas firmarlo con tu Apple ID. Una opción
es Sideloadly (Mac/Windows), que firma el IPA al instalarlo.
Las apps con cuenta Apple gratuita suelen requerir renovación cada 7 días.

## Servidor en macOS Sonoma

Utiliza el servidor \`monitor.py\` y \`start.command\` del paquete
**Monitor-Hackintosh-iPad.zip** generado en la conversación. En el Mac:

\`\`\`bash
cd ~/Downloads/Monitor-Hackintosh-iPad
bash start.command
\`\`\`

Se escucha el puerto TCP **8765** y se sirve
\`http://IP-DE-TU-MAC:8765/api/status\`. Introduce en la app únicamente
la IP del Hackintosh y pulsa **Conectar**.

El servidor y el iPad deben estar en la misma red local.
No publiques el puerto en Internet; el endpoint no tiene autenticación.
La app guarda la dirección introducida en el propio iPad.

## Sensores opcionales

\`\`\`bash
brew install osx-cpu-temp
brew tap dkorunic/tap
brew install ismc
\`\`\`

Es posible que GPU, sensores y ventiladores aparezcan como «—»:
depende de la EFI, VirtualSMC, SMCProcessor, SMCSuperIO y el driver GPU.

## Herramientas

- Xcode 15.4 (runner \`macos-14\`) y deployment target iOS 12.0.
- XcodeGen para generar el proyecto Xcode a partir de \`project.yml\`.
- No utiliza dependencias ni librerías de terceros en iOS.
