# Подготовка установки на iPhone

Повторная проверка по запросу установки на физический телефон: `Tools/verify.sh` завершился с exit 0; Core 24/24, Swift Testing 40/40, Application/persistence и Simulator build прошли. Release `iphoneos` без подписи также собран успешно. Лог: [phone-preflight.txt](verification/phone-preflight.txt). Повторно обнаружены 0 действительных signing identities и отсутствие физического iPhone в `xcdevice list`. Для установки выберите свою Team в Xcode и подключите устройство по USB; затем Run установит подписанную development-сборку.

Дата проверки: 18 октября 2026 года. Цель этого документа — локальный запуск на личном iPhone или подготовка к TestFlight. Публикация в App Store и загрузка сборки в App Store Connect в рамках этой проверки не выполнялись.

## Текущее состояние проекта

| Параметр | Результат |
|---|---|
| Xcode | Xcode 27.1, build 27A9275 |
| Проект / схема | `PokerTrainer.xcodeproj` / `PokerTrainer` |
| Основная цель | `PokerTrainer`; UI tests — `PokerTrainerUITests` |
| Конфигурации | Debug и Release |
| Минимальная iOS | 17.0 |
| Bundle identifier | `org.pokerpractice.native` |
| Отображаемое имя | `Учебный стол` |
| Версия / build | `0.1.0` / `1` |
| Code signing | Automatic; `Apple Development`; `DEVELOPMENT_TEAM` не задан, profile specifier не задан |
| Действительные identities в Keychain | 0 |
| Физический iPhone | Не обнаружен в `xcrun xcdevice list`; доступны iPhone Simulator и Mac |
| Исходники `.mobileprovision` / entitlements | В репозитории не найдены |

`org.pokerpractice.native` — текущий идентификатор проекта; его глобальная доступность и регистрация в аккаунте Apple не проверены. Xcode потребует свободный уникальный App ID для выбранной Team. Название `Riverframe` из `replica/brand.md` остаётся кандидатом и не установлено в приложении; текущая иконка на устройстве подписывается именем `Учебный стол`.

## Локальный preflight

| Проверка | Фактический результат |
|---|---|
| `xcodebuild -version` | Xcode 27.1 доступен |
| `xcodebuild -list -project PokerTrainer.xcodeproj` | Схемы `PokerCore` и `PokerTrainer` обнаружены |
| `./Tools/verify.sh` | PASS, exit 0: Core 24/24 группы, 10 937 assertions; Swift Testing 40/40; Application/storage checks; `plutil`; iOS Simulator build |
| Release-сборка `generic/platform=iOS`, `CODE_SIGNING_ALLOWED=NO` | PASS, `BUILD SUCCEEDED`; артефакт не подписан |
| Code signing identity | BLOCKED: `security find-identity -v -p codesigning` сообщает `0 valid identities found` |
| Подключённый iPhone | BLOCKED: физического iPhone в списке устройств нет |
| Открытые критические дефекты | В `replica/tests/bugs.md` все зарегистрированные S1/S2 имеют статус исправленных; полный UI-набор этой командой повторно не запускался |

Логи последнего preflight: [ios-build.txt](verification/ios-build.txt), [unit-tests.txt](verification/unit-tests.txt), [core-checks.txt](verification/core-checks.txt), [app-checks.txt](verification/app-checks.txt), [iphoneos-release-unsigned.txt](verification/iphoneos-release-unsigned.txt). История ранее выполненной UI- и офлайн-приёмки находится в [tests/report.md](tests/report.md).

Проверки `npm run build`, Playwright, web parity, web brand sweep и веб-валидатор листинга к нативному SwiftUI-проекту неприменимы. Полноценные веб-страницы политики, домен, production services и рекламная аналитика для личной установки не нужны. Локальный JSON App Store-листинга является маркетинговым черновиком и не используется в Xcode signing.

## Установка прямо из Xcode — рекомендуемый путь

1. Подключите iPhone к Mac по USB, разблокируйте его и подтвердите **Trust This Computer**.
2. На iPhone включите Developer Mode в **Settings → Privacy & Security → Developer Mode**, затем подтвердите перезапуск и системное подтверждение режима.
3. Откройте `PokerTrainer.xcodeproj` в Xcode. В **Xcode → Settings → Accounts** войдите в свой Apple Account. Для локального запуска можно выбрать отображаемую Xcode команду **Personal Team**; платное членство не требуется для такого личного тестирования.
4. В Project navigator выберите проект **PokerTrainer**, затем target **PokerTrainer → Signing & Capabilities**. Оставьте **Automatically manage signing** включённым и выберите свою Team.
5. Если Xcode отклонит текущий `org.pokerpractice.native`, задайте в поле **Bundle Identifier** уникальное reverse-DNS имя, контролируемое вами, например на основе собственного домена. Не используйте домен, который вам не принадлежит. Xcode автоматически подготовит development signing для выбранной Team и устройства.
6. Выберите физический iPhone в списке Run destinations и нажмите **Run**. Подтвердите регистрацию устройства, если Xcode покажет соответствующий запрос.
7. Если iOS попросит подтвердить разработчика, следуйте системному экрану доверия. Повторно запустите приложение через Xcode.

Apple описывает этот процесс как вход в Xcode с Apple Account, выбор уникального bundle ID и автоматическую регистрацию устройства/создание development profile: [Running your app on a device](https://developer.apple.com/documentation/xcode/building-and-running-an-app?changes=_9&language=objc), [Distributing to registered devices](https://developer.apple.com/documentation/xcode/distributing-your-app-to-registered-devices). Проверено 18.10.2026.

### Ограничения бесплатной Personal Team

Apple указывает лимиты Personal Team: до 10 App IDs и 3 устройств; регистрация и provisioning profiles истекают через 7 дней. После окончания срока приложение потребуется заново собрать и установить через Xcode. См. [Developer account overview — Enable a personal team in Xcode](https://developer.apple.com/help/account/basics/about-your-developer-account), проверено 18.10.2026.

## TestFlight — подготовка на будущее

Текущая машина не имеет видимой Developer signing identity, Team, подключённого iPhone или подтверждённого App Store Connect app record. TestFlight-пакет сейчас не подготовлен и не отправлен.

Для дальнейшей внутренней бета-установки потребуется:

1. Действительное членство Apple Developer Program и доступ к App Store Connect.
2. Выбранная и зарегистрированная Team, окончательный уникальный bundle ID и app record в App Store Connect.
3. Подписанная Release-сборка и version/build number, новые значения которых возрастают для каждой загрузки.
4. Бета-описание, контакт для обратной связи и ответы на вопросы export compliance в App Store Connect.
5. Загрузка архива через Xcode Organizer и ожидание обработки Apple; затем назначение сборки внутренней группе TestFlight.

Эти шаги приведены для самостоятельного выполнения владельцем аккаунта. Эта сессия не входит в аккаунт и не отправляет бинарные файлы во внешние сервисы. Apple описывает создание app record и обработку загрузок в [App Store Connect workflow](https://developer.apple.com/help/app-store-connect/get-started/app-store-connect-workflow) и [Upload builds](https://developer.apple.com/help/app-store-connect/manage-builds/upload-builds/). TestFlight принимает бета-сборки после загрузки и обработки; тестовая сборка доступна до 90 дней: [TestFlight Overview](https://developer.apple.com/help/app-store-connect/test-a-beta-version/testflight-overview/). Источники проверены 18.10.2026.

Первый TestFlight build для внешних тестеров может требовать review Apple. Текущая задача ограничена личной установкой и внутренней готовностью; внешняя группа не создавалась.

## Что остаётся для установки

- Войти в Apple Account в Xcode и выбрать свою Team.
- Подключить физический iPhone и включить Developer Mode.
- Проверить доступность или заменить bundle ID на уникальный в выбранной Team.
- Дать Xcode создать действительный signing certificate/provisioning profile и запустить Debug-сборку на устройстве.

Для TestFlight дополнительно нужны активная программа Apple Developer, App Store Connect app record, заполненные тестовые сведения, подписанный архив и загрузка через Organizer владельцем аккаунта.

## Непроверенные пункты

- Установка на физический iPhone и запуск подписанной сборки: физическое устройство не подключено.
- Работоспособность текущего bundle ID в Apple Developer portal: не проверена.
- Наличие Apple Account или платного членства в Xcode/App Store Connect: по локальным данным это установить нельзя; проверено только отсутствие доступного signing identity в Keychain.
- Архивирование с подписью, загрузка TestFlight, обработка Apple, установка через TestFlight: не выполнялись.
- Финальная коммерческая готовность, App Store metadata review и юридическая проверка имени: остаются отдельными задачами.

## Ограничение этой проверки

Выполнены локальные автоматические проверки и сборки без подписи. Устанавливаемый на физическое устройство артефакт требует настроить signing в вашей Xcode Team. Никаких публикаций, App Store Connect upload или TestFlight distribution не выполнялось.
