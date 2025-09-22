# README ALTCRAFT IOS SDK

# Содержание README ALTCRAFT iOS SDK

* Виды авторизации API-запросов

  * JWT-авторизация (рекомендуемый способ)
  * Авторизация с использованием ролевого токена Altcraft
* Предварительные условия
* Загрузка пакета Altcraft Mobile SDK (Swift Package Manager)
* Подготовка приложения

  * Настройки таргета

    * Signing & Capabilities (PushNotifications, AppGroups, Background Modes)
    * Info (Permitted background task scheduler identifiers → `lib.Altcraft.bgTask.systemControl`)
  * Настройка SDK в `AppDelegate.application(_:didFinishLaunchingWithOptions:)`

    * Установка App Group (`setAppGroup`)
    * Регистрация фоновых задач (`backgroundTasks.registerBackgroundTask`)
    * (Опционально) Инициализация `UNUserNotificationCenter` через `notificationManager.registerForPushNotifications`
* Реализация протоколов SDK

  * `JWTInterface`
  * Протоколы запроса/удаления push-токена

    * `APNSInterface`
    * `FCMInterface`
    * `HMSInterface`
* Подготовка Notification Service Extension (NSE)

  * Создание таргета NSE
  * Настройка (General / Signing & Capabilities)
  * Интеграция в `UNNotificationServiceExtension`

    * `AltcraftPushReceiver.isAltcraftPush`
    * `AltcraftPushReceiver.didReceive`
    * `serviceExtensionTimeWillExpire`
    * Повторная регистрация `JWTProvider` в NSE
* Инициализация SDK

  * Конфигурация (`AltcraftConfiguration`, `AppInfo`, `providerPriorityList`)
  * Выполнение инициализации (`AltcraftSDK.shared.initialization`)
  * Пример порядка инициализации в `AppDelegate`
* Получение событий SDK (объект `eventSDKFunctions`)

  * Подписка `subscribe` / отписка `unsubscribe`
  * Модели событий: `Event`, `ErrorEvent`, `RetryEvent`
  * Пример структуры события успешной подписки
* Работа со статусами подписки

  * Изменение статуса: `pushSubscribe`, `pushSuspend`, `pushUnSubscribe`

    * Параметры: `sync`, `profileFields`, `customFields`, `cats`, `replace`, `skipTriggers`
    * Формат `ResponseWithHttp` и чтение данных
  * `unSuspendPushSubscription` (сценарии LogIn/LogOut)
  * Запрос статуса:

    * `getStatusOfLatestSubscription`
    * `getStatusForCurrentSubscription`
    * `getStatusOfLatestSubscriptionForProvider`
  * `actionField(key:)` — функциональные поля профиля
* Работа с пуш-провайдерами (объект `pushTokenFunction`)

  * Ручная установка токена `setPushToken`
  * Получение текущего токена `getPushToken`
  * Регистрация провайдеров: `setAPNSTokenProvider`, `setFCMTokenProvider`, `setHMSTokenProvider`
  * Смена приоритета провайдеров `changePushProviderPriorityList`
  * Удаление токена `deleteDeviceToken`
  * Форс-обновление токена `forcedTokenUpdate`
* Ручная регистрация push-событий (объект `pushEventFunctions`)

  * `deliveryEvent(from:)`
  * `openEvent(from:)`
* Передача push-уведомления в SDK (класс `AltcraftPushReceiver`)

  * `isAltcraftPush(_:)`
  * `didReceive(_:withContentHandler:)`
  * `serviceExtensionTimeWillExpire()`
* Очистка данных SDK

  * `AltcraftSDK.shared.clear(completion:)`
* Публичные функции и классы SDK (обзор API)

  * `AltcraftSDK`
  * `AltcraftPushReceiver`
  * `AltcraftConfiguration` (+ `Builder`)
  * Публичные структуры: `TokenData`, `AppInfo`, `ResponseWithHttp`, `Response`, `ProfileData`, `SubscriptionData`, `CategoryData`, `JSONValue`

---

## Виды авторизации API-запросов

Взаимодействие между клиентом (приложением) и сервером Altcraft осуществляется с использованием одного из двух способов авторизации API-запросов.

### JWT-авторизация (рекомендуемый способ)

Данный тип авторизации использует JWT-токен, который приложение передаёт в SDK. Токен добавляется в заголовок каждого запроса.

**JWT (JSON Web Token)** — это строка в формате JSON, содержащая claims (набор данных), подписанных для проверки подлинности и целостности.

<br>

Токен формируется и подписывается ключом шифрования на стороне серверной части клиента (ключи шифрования не хранятся в приложении). По запросу SDK, приложение обязано передать полученный с сервера JWT токен. 

**Преимущества:**

* Повышенная безопасность API-запросов.
* Возможность поиска профилей по любым идентификаторам (email, телефон, custom ID).
* Поддержка нескольких пользователей на одном устройстве.
* Восстановление доступа к профилю после переустановки приложения.
* Идентификация конкретного профиля на разных устройствах.

### Авторизация с использованием ролевого токена Altcraft

Альтернативный способ авторизации — использование ролевого токена (*rToken*), переданного в параметры конфигурации SDK.
В этом случае запросы содержат заголовок с ролевым токеном.

**Особенности:**

* Поиск профилей возможен только по push-токену устройства (например, FCM).
* Если push-токен изменился и не был передан на сервер (например, после удаления и переустановки приложения), связь с профилем будет потеряна / создастся новый профиль.

**Ограничения:**

* Потеря связи с профилем при изменении push-токена, которое не было зафиксировано на сервере Altcraft.
* Отсутствие возможности использовать приложение для разных профилей на одном устройстве.
* Невозможность регистрации одного пользователя на другом устройстве.

## Предварительные условия

- SDK провайдеров push уведомлений интегрированы в проект приложения (см. инструкции по интеграции push провайдеров).

## Загрузка пакета Altcraft Mobile SDK

- Выполните загрузку пакета Altcraft с помощью Swift package manager. 

## Подготовка приложения 

### Настройки таргета

Выполните настройки таргета приложения:

   - Signing & Capabilities:
     - PushNotifications;
     - AppGroups - укажите идентификатор для группы (добавление идентификатора App Group необходимо обмена информацией с Notification Service Extension); 
     - Background Modes - выберите Background fetch, Background processing.

   - Info: 
    - Добавьте ключ `Permitted background task scheduler identifiers` и Value для ключа "lib.Altcraft.bgTask.systemControl". Это необходимо для регистрации bgTask задачи которая будет выполнять повтор неудачных запросов к серверу в Background режиме;


### Настройка SDK В AppDelegate.application(_:didFinishLaunchingWithOptions:)

- передача идентификатора AppGroup в SDK
- регистрация BGTask - фоновых задач SDK 
- опционально - инициализация функций UNUserNotificationCenter на стороне SDK
    
#### Установка идентификатора AppGroup

Добавление идентификатора App Group необходимо для обмена информацией с Notification Service Extension. Требуется для корректной работы SDK. Выполняется с помощью функции setAppGroup(): 
    
• **public func setAppGroup(groupName: String): Void** - функция для установки идентификатора AppGroup в SDK.

```swift
// Установка App Group и инициализация Core Data под shared-контейнер
AltcraftSDK.shared.setAppGroup(groupName: String)
```

#### Регистрация BGTask SDK     

Регистрация фоновых задач SDK необходима для повторной отправки неуспешных запросов в фоновом режиме. 

• **public func registerBackgroundTask(): Void** - функция для регистрации BGTask SDK.

```swift
// Зарегистрировать фоновую SDK задачу и запланировать периодический запуск (~каждые 3 часа)
AltcraftSDK.shared.backgroundTasks.registerBackgroundTask()
```

#### Инициализация функций UNUserNotificationCenter (опционально)

SDK содержит класс NotificationManager который выполняет следующие задачи - 

 - настраивает UNUserNotificationCenter и запрашивает разрешение (alert/sound/badge).
 - Обеспечивает вызов UIApplication.registerForRemoteNotifications() и гарантирует корректную регистрацию в APNs.
 - отображает уведомления в foreground.  
 - обрабатывает клики по уведомлениям и кнопкам - открывает ссылки / deep link.
 - регистрирует push событие открытия (open).

Использование этого класса опционально: вы можете заменить его своей реализацией. Для этого: 

 - Назначьте делегата центра уведомлений: UNUserNotificationCenter.current().delegate = self.
 - Запросите разрешения на уведомления и вызовите UIApplication.shared.registerForRemoteNotifications() строго на главном потоке.
 - Реализуйте метод userNotificationCenter(_:willPresent:withCompletionHandler:) для отображения уведомлений в foreground (баннер/алерт/звук/бейдж).
 - Вызовите AltcraftSDK.shared.pushEventFunctions.openEvent(from:) в userNotificationCenter(_:didReceive:withCompletionHandler:) при обработке нажатия на уведомление (регистрируйте событие «open»).
 - Реализуйте собственную логику обработки кликов по уведомлению (URL/диплинк/кнопки) и предусмотрите fallback-сценарий (навигацию по умолчанию при отсутствии валидной ссылки).

  
 Для использования класса NotificationManager SDK вызовите функцию func registerForPushNotifications() в AppDelegate.application(_:didFinishLaunchingWithOptions:)
  
**func registerForPushNotifications(for application: UIApplication, completion: ((_ granted: Bool, _ error: Error?) -> Void)? = nil): Void** - назначает делегата, запрашивает разрешение у пользователя и регистрирует приложение для получения push-уведомлений на стороне SDK. 
  
> Пример установки идентификатора AppGroup,  регистрации BGTask и инициализация функций UNUserNotificationCenter на стороне SDK(опционально) в AppDelegate.application(_:didFinishLaunchingWithOptions:) 

```swift
class AppDelegate: UIResponder, UIApplicationDelegate, MessagingDelegate, UNUserNotificationCenterDelegate {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {
        let appGroup = "group.your.name.example"

        //установка идентификатора AppGroup
        AltcraftSDK.shared.setAppGroup(groupName: appGroup)
        
        //регистрация фоновых задач SDK 
        AltcraftSDK.shared.backgroundTasks.registerBackgroundTask()
        
        //инициализация функций UNUserNotificationCenter SDK
        AltcraftSDK.shared.notificationManager.registerForPushNotifications(for: application)
        
        //остальные функции
        
        return true
    }
    //остальные функции AppDelegate
}
```

### Реализация протоколов SDK

SDK содержит публичные протоколы которые могут быть реализованы на стороне приложения. 
   
**Обратите внимание** 
Регистрируйте провайдеры в application(_:didFinishLaunchingWithOptions:) (AppDelegate). Данная точка регистрации гарантирует раннюю, однократную и детерминированную регистрацию при старте процесса, в том числе в background.

#### JWTInterface:  

Протокол запроса JWT токена. Предоставляет актуальный JWT токен из приложения по запросу SDK. Реализация данного протокола требуется если используется JWT аутентификация api запросов. JWT подтверждает что пользовательские идентификаторы аутентифицированы приложением. 
Реализация JWT аутентификации обязательна если используется тип матчинга (https://guides.altcraft.com/user-guide/profiles-and-databases/matching/#peculiarities-of-matching) отличный от Push данных из подписки, например, идентификатор пользователя - email или телефон. 

**Обратите внимание** 
getJWT() — синхронный функция. Поток выполнения SDK будет приостановлен до получения JWT.Рекомендуется, чтобы getJWT() возвращал значение немедленно — из кэша (in-memory, UserDefaults, Keychain) это ускорит выполнение запросов.Желательно подготовить актуальный JWT как можно раньше, например на старте приложения, и сохранить его в кэш, чтобы при обращении SDK токен был доступен без задержек.При отсутствии значения допустимо вернуть null.

---
Протокол SDK:

```swift
public protocol JWTInterface {
    func getToken() -> String?
}
``` 
---
 Реализация на стороне приложения: 

```swift
import Altcraft

class JWTProvider: JWTInterface {
    func getToken() -> String? {
         //ваш код возвращающий JWT
      }
}
``` 
---
Регистрация провайдера в application(_:didFinishLaunchingWithOptions:) (AppDelegate):

```swift

class AppDelegate: UIResponder, UIApplicationDelegate, MessagingDelegate, UNUserNotificationCenterDelegate {
  func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
    //остальной код
    
    AltcraftSDK.setJWTProvider(provider: JWTProvider())
  }
  //остальные функции
}
``` 

#### Протоколы запроса и удаления push токена

Данная реализация протоколов запроса и удаления push-токена гарантирует использование актуального токена и обеспечивает возможность динамической смены провайдеров по требованию клиента. 

**APNSInterface** - Протокол запроса push токена APNs. В данном протоколе отсутствует функция удаления токена в отличии от других протоколов push провайдеров. 

---
Протокол SDK:

```swift
public protocol APNSInterface {

    func getToken(completion: @escaping (String?) -> Void)
}
``` 
---
Рекомендуемая реализация на стороне приложения: 

```swift
import Altcraft

class APNSProvider: APNSInterface {
    func getToken(completion: @escaping (String?) -> Void) {
        //ваш код возвращающий apns токен
    }
}
``` 
---
Регистрация провайдера в application(_:didFinishLaunchingWithOptions:) (AppDelegate):

```swift
class AppDelegate: UIResponder, UIApplicationDelegate, MessagingDelegate, UNUserNotificationCenterDelegate {
  func application(
  _ application: UIApplication, 
  didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
    //остальной код
    
    AltcraftSDK.pushTokenFunction.setAPNSTokenProvider(APNSProvider())
  }
  //остальные функции
}
``` 

**FCMInterface** - Протокол запроса и удаления push токена FCM. 

---
Протокол SDK:

```swift
public protocol FCMInterface {
    func getToken(completion: @escaping (String?) -> Void)
    
    func deleteToken(completion: @escaping (Bool) -> Void)
}
``` 

---
Рекомендуемая реализация на стороне приложения: 

```swift
import FirebaseMessaging
import Altcraft

class FCMProvider: FCMInterface {
    func getToken(completion: @escaping (String?) -> Void) {
        Messaging.messaging().token { token, error in
            if error != nil {
                completion(nil)
            } else {
                completion(token)
            }
        }
    }

    func deleteToken(completion: @escaping (Bool) -> Void) {
        Messaging.messaging().deleteToken { error in
            if error != nil {
                completion(false)
            } else {
                completion(true)
            }
        }
    }
}
``` 

---
Регистрация провайдера в application(_:didFinishLaunchingWithOptions:) (AppDelegate):

```swift
class AppDelegate: UIResponder, UIApplicationDelegate, MessagingDelegate, UNUserNotificationCenterDelegate {
  func application(
  _ application: UIApplication, 
  didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
    //остальной код
    
    AltcraftSDK.pushTokenFunction.setFCMTokenProvider(FCMProvider())
  }
  //остальные функции
}
``` 

**HMSInterface** - Интерфейс запроса и удаления push токена HMS

---
Протокол SDK:

```swift
public protocol HMSInterface {
    
    func getToken(completion: @escaping (String?) -> Void)

    func deleteToken(completion: @escaping (Bool) -> Void)
}
``` 

---
Рекомендуемая реализация на стороне приложения: 

```swift
class HMSProvider: HMSInterface {
    
    func getToken(completion: @escaping (String?) -> Void) {
    
        //переменная содержащая apns токен который в дальнейшем 
        //передается в HmsInstanceId.getInstance().getToken(apnsToken)
        guard let apnsToken = getAPNsTokenFromUserDefault() else {
            completion(nil)
            return
        }


        let token = HmsInstanceId.getInstance().getToken(apnsToken)
        completion(token)
    }
    
    
    func deleteToken(completion: @escaping (Bool) -> Void) {
        HmsInstanceId.getInstance().deleteToken()
        completion(true)
    }
}
``` 

---
Регистрация провайдера в application(_:didFinishLaunchingWithOptions:) (AppDelegate):

```swift
class AppDelegate: UIResponder, UIApplicationDelegate, MessagingDelegate, UNUserNotificationCenterDelegate {
  func application(
  _ application: UIApplication, 
  didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
    //остальной код
    
    AltcraftSDK.pushTokenFunction.setHMSTokenProvider(HMSProvider())
  }
  //остальные функции
}
``` 

> Реализуйте интерфейсы для тех push провайдеров которые используются в вашем проекте. 

   
## Подготовка Notification Service Extension 

Добавление расширения NSE необходимо для поддержки Rich Push и гарантированной регистрации событий доставки.

1. Создайте расширение приложения Notification Service Extension:

   - Выполните File -> New -> Target -> Notification Service Extension.
   - Выберите название (Product Name) для таргета расширения .
   - Активируйте

2. Выполните Notification Service Extension:
   
   - General:
      - Укажите Minimum Deployments - это параметр сборки в Xcode, который определяет минимальную версию операционной системы, на которой будет работать Notification Service Extension.
      - Добавьте фреймворк Altcraft в разделе "Frameworks,Libraries and Embedded Content"
    
   - Signing & Capabilities:
      - AppGroups - укажите идентификатор AppGroup.
      
      
3. Настройте SDK в UNNotificationServiceExtension:

   1) Импортируйте фреймворк Altcraft 
   2) Создайте экземпляр AltcraftPushReceiver()
   3) В функции didReceive(_ request: UNNotificationRequest, withContentHandler contentHandler: @escaping (UNNotificationContent) -> Void) передайте идентификатор appGroup в функцию AltcraftSDK.shared.setAppGroup(groupName: appGroupsName). Данный идентификатор должен соответствовать идентификатору переданному в SDK в таргете приложения.
   4) В функции didReceive(_ request: UNNotificationRequest, withContentHandler contentHandler: @escaping (UNNotificationContent) -> Void) установите провайдер JWT(если используется jwt аутентификация запросов): AltcraftSDK.shared.setJWTProvider(provider: jwtProvider)
   5) В функции didReceive(_ request: UNNotificationRequest, withContentHandler contentHandler: @escaping (UNNotificationContent) -> Void) выполните проверку источника уведомления с помощью функции isAltcraftPush(request) класса AltcraftPushReceiver(): service.isAltcraftPush(request)
   6) В функции didReceive(_ request: UNNotificationRequest, withContentHandler contentHandler: @escaping (UNNotificationContent) -> Void) после проверки источника уведомления, если уведомление Altcraft передайте UNNotificationRequest и contentHandler в функцию didReceive класса AltcraftPushReceiver(): self.service.didReceive(request, withContentHandler: contentHandler)
   
**Приведенный ниже пример реализации UNNotificationServiceExtension - можно использовать как готовый класс. Замените весь автоматически сгенерированный код на эту реализацию, если вам не требуется дополнительная логика.** Если вы уже используете UNNotificationServiceExtension интегрируйте функции Altcraft в свою реализацию. 
   
```swift
import Altcraft
import UserNotifications

class NotificationService: UNNotificationServiceExtension {
    var service = AltcraftPushReceiver()
    
    /// - important! Set app groups name.
    var appGroupsName = "your.app.group"
    let jwtProvider = JWTProvider()

    override func didReceive(_ request: UNNotificationRequest, withContentHandler contentHandler: @escaping (UNNotificationContent) -> Void) {
        
        AltcraftSDK.shared.setAppGroup(groupName: appGroupsName)
        AltcraftSDK.shared.setJWTProvider(provider: jwtProvider)

        if service.isAltcraftPush(request) {
            self.service.didReceive(request, withContentHandler: contentHandler)
        } else {
            contentHandler(request.content)
        }
    }
    override func serviceExtensionTimeWillExpire() {service.serviceExtensionTimeWillExpire()}
}
``` 

**Обратите внимание** Таргет приложения и таргет Notification Service Extension работают в отдельных процессах и не разделяют общие объекты. Поэтому для корректной обработки уведомлений SDK необходимо зарегистрировать JWTProvider также в расширении NSE — например, в методе
didReceive(_ request: UNNotificationRequest, withContentHandler contentHandler: @escaping (UNNotificationContent) -> Void). Это обеспечивает доступ SDK к токену авторизации при отправке push-события доставки (delivery_event).

## Инициализация SDK

### Конфигурация SDK 

Для передачи параметров конфигурации испоользуется класс AltcraftConfiguration:

```swift
public final class AltcraftConfiguration {
    private let apiUrl: String
    private let rToken: String?
    private var appInfo: AppInfo?
    private var providerPriorityList: [String]?
}
```
**Описание параметров:**
   
• **apiUrl** - (обязательный параметр) url адрес конечной точки Altcraft API. 

• **rToken** - (опциональный параметр) ролевой токен Altcraft. Идентифицирует ресурс, базу данных, аккаунт.  Используется если единственный тип матчинга идентефицирующий подписку - push токен устройства созданный провайдером пуш уведомлений (например токен fcm).

• **appInfo**  — (опциональный параметр) представляет базовые метаданные приложения, используемые в Firebase Analytics. 

  Для установки значения этого параметра используйте публичную структуру SDK AppInfo:

```swift
public struct AppInfo: Codable {
    
    /// Уникальный идентификатор приложения (Firebase `app_id`)
    public var appID: String
    
    /// Уникальный идентификатор установки приложения (Firebase `app_instance_id`)
    public var appIID: String
    
    /// Версия приложения (Firebase `app_version`)
    public var appVer: String
}
```

• **providerPriorityList** — (опциональный параметр) список содержащий строковые названия провайдеров push-уведомлений используемые в платформе Altcraft. 
SDK содержит публичные константы которые могут быть использованы как заначения для этого списка: 

```swift
public enum Constants {
    public enum ProviderName {
        /// The provider name for Firebase.
        public static let firebase = "ios-firebase"

        /// The provider name for APNs.
        public static let apns = "ios-apns"

        /// The provider name for HMS.
        public static let huawei = "ios-huawei"
    }
}
```
Все публичные константы SDK находятся в enum Constants 

Параметр **`providerPriorityList`** устанавливает приоритет использования push-провайдеров.

* Используется для **автоматического обновления push-токена подписки**, если токен более приоритетного провайдера недоступен.
* Приоритет определяется **индексом в массиве**:
    - элемент с индексом **0** — самый приоритетный.

Пример:

```swift
providerPriorityList = [
    Constants.ProviderName.apns,
    Constants.ProviderName.firebase,
    Constants.ProviderName.huawei
]
```

* SDK сначала запросит токен **APNs**.
* Если APNs недоступен → запросит токен **FCM**.
* Если FCM недоступен → запросит токен **HMS**.
* Работает при условии, что в приложении реализованы интерфейсы `APNSInterface`, `FCMInterface`, `HMSInterface`.

Значение по умолчанию:

Приоритет в SDK (если параметр не указан):

```
apns → firebase → huawei
```

* Список может содержать **один элемент** — в этом случае будет использоваться только один провайдер, независимо от доступности токена.
* Указывать параметр не обязательно, если:
    - в проекте используется только один push-провайдер,
    - или приоритет по умолчанию (`apns → firebase → huawei`) соответствует требованиям.
* Параметр удобен для **быстрого перехода** на использование токена указанного провайдера во время инициализации SDK.


> Сборка файла конфигурации происходит после вызова функции build() класса AltcraftConfiguration.Builder():  AltcraftConfiguration.Builder().build().  

### Выполнение инициализация SDK 

• **public func initialization(configuration: AltcraftConfiguration?, completion: ((Bool) -> Void)? = nil)** - функция выполняющая инициализацию SDK. 

```swift
// Инициализация SDK и установка конфигурации
AltcraftSDK.shared.initialization(configuration: AltcraftConfiguration?, completion: ((Bool) -> Void)? = nil)
```

**Обратите внимание** Функция AltcraftSDK.shared.initialization() может быть вызвана в тот момент когда это требуется, но после установки идентификатора AppGroup и провайдеров реализующих протоколы SDK. Выполнение запросов следует производить после установки конфигурации.  

Функция initialization(configuration: AltcraftConfiguration?, completion: ((Bool) -> Void)? = nil) ожидает файл конфигурации AltcraftConfiguration для которого установлены необходимые значения и выполнена сборка. 

```swift
 let config = AltcraftConfiguration.Builder()
        .setApiUrl("your apiUrl")
        .setRToken("your rToken")
        .setAppInfo(AppInfo(appID: "your appID", appIID: "your appIID", appVer: "your appVer"))
        .setProviderPriorityList([Constants.ProviderName.firebase])
        .build()
```
    
Пример правильного порядка инициализации SDK в AppDelegate.application(_:didFinishLaunchingWithOptions:) после установки идентификатора AppGroup и регистрации провайдеров:

```swift
class AppDelegate: UIResponder, UIApplicationDelegate, MessagingDelegate, UNUserNotificationCenterDelegate {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {
        let appGroup = "group.altcraft.apns.example"
        
        AltcraftSDK.shared.setAppGroup(groupName: appGroup)
        AltcraftSDK.shared.backgroundTasks.registerBackgroundTask()
        AltcraftSDK.shared.setJWTProvider(provider: JWTProvider())
        AltcraftSDK.shared.pushTokenFunction.setAPNSTokenProvider(APNSProvider())
        AltcraftSDK.shared.pushTokenFunction.setFCMTokenProvider(FCMProvider())
        AltcraftSDK.shared.pushTokenFunction.setHMSTokenProvider(HMSProvider())
        AltcraftSDK.shared.notificationManager.registerForPushNotifications(for: application)
        
        let config = AltcraftConfiguration.Builder()
            .setApiUrl("your apiUrl")
            .setRToken("your rToken")
            .setAppInfo(AppInfo(appID: "your appID", appIID: "your appIID", appVer: "your appVer"))
            .setProviderPriorityList([Constants.ProviderName.firebase])
            .build()
        
        AltcraftSDK.shared.initialization(configuration: config) { success in
            if success {
               //выполнить после успешной инициализации
            }
        }
        
        //остальные функции
        
        return true
    }
    //остальные функции AppDelegate
}
```

## Получение событий SDK в приложении. Функции объекта Events.

```
AltcraftSDK
└── static let shared: AltcraftSDK
    // Поток SDK-событий (один активный подписчик)
    └── eventSDKFunctions: SDKEvents
        // Подписаться на события SDK (заменяет существующего подписчика)
        ├── subscribe(
        │       callback: @escaping (Event) -> Void
        │   ): Void
        // Отписаться от событий (колбэк остаётся назначенным, доставка останавливается)
        └── unsubscribe(): Void
```

Для того чтобы подписаться и получать события SDK в приложении воспользуйтесь функцией subscribe() объекта SDKEvents SDK:

• **func subscribe(callback: @escaping (Event) -> Void): Void** - при возникновении события SDK вызывает callback и передаёт в него экземпляр класса Event(или его наследника). В приложении может быть только один активный подписчик на события SDK.

> пример использования функции: 

```swift
AltcraftSDK.shared.eventSDKFunctions.subscribe { event in
  //событие
}
```

Все события, передаваемые SDK, являются экземплярами Event или его наследников:

```swift
open class Event: Hashable {
    public let id = UUID()
    public let function: String
    public let message: String?
    public let eventCode: Int?
    public let value: [String: Any?]?
    public let date: Date
}

open class ErrorEvent: Event {
    public override init(
        function: String,
        message: String? = nil,
        eventCode: Int? = nil,
        value: [String: Any?]? = nil,
        date: Date = Date()
    ) {
        super.init(
            function: function,
            message: message,
            eventCode: eventCode,
            value: value,
            date: date
        )
    }
}

public class RetryEvent: ErrorEvent {
    public override init(
        function: String,
        message: String? = nil,
        eventCode: Int? = 0,
        value: [String: Any?]? = nil,
        date: Date = Date()
    ) {
        super.init(
            function: function,
            message: message,
            eventCode: eventCode,
            value: value,
            date: date
        )
    }
}
```

* **Event** — общее событие (информация, успешные запросы);
* **Error** — событие об ошибке;
* **RetryError** — событие об ошибке при выполнения запроса для которого предусмотрен автоматический повтор выполнения на стороне SDK.

Каждое событие содержит поля: 
 - function - имя функции вызвовшей событие;
 - eventCode - внутренний код события SDK(список событий SDK представлен в пункте "События SDK");
 - eventMessage - сообщение события, 
 - eventValue - произвольные данные [String: Any?]? которые добавляются к некоторым событиям как полезная нагрузка;
 - date - время события.

 > пример содержания события успешной подписки на push уведомления:
 
```
├─ function: processResponse
├─ eventCode: 230
├─ message: "successful request: push/subscribe"
├─ value
│  ├─ http code: 200
│  └─ response
│     ├─ error: 0
│     ├─ errorText: ""
│     └─ profile
│        ├─ id: // ID профиля
│        ├─ status: subscribed
│        ├─ isTest: false
│        └─ subscription
│           ├─ subscriptionId: // push токен подписки
│           ├─ hashId: // хеш ID
│           ├─ provider: "ios-apns"
│           ├─ status: subscribed
│           ├─ fields
│           │  ├─ _ad_id: // рекламный идентификатор google service
│           │  ├─ _ad_track: false
│           │  ├─ _app_id: "AltcraftMobile"
│           │  ├─ _app_iid: "1.0.0"
│           │  ├─ _app_ver: {"raw":"1.0.0","ver":[1,0]}
│           │  ├─ _device_model: "iPhone14,7"
│           │  ├─ _device_name: "iPhone"
│           │  ├─ _device_type: "mob"
│           │  ├─ _os: "Android"
│           │  ├─ _os_language: "ru"
│           │  ├─ _os_tz: "+0300"
│           │  └─ _os_ver: {"raw":"18.6.2","ver":"[\"18.0\", \"6.0\", \"2.0\"]"}
│           └─ cats
│              └─ [ { name: "cats_1", title: "cats_1", steady: false, active: false } ]
└─ date: Tue Aug 12 15:49:20 GMT+03:00 2025
```
отписаться от событий SDK можно с помощью функции unsubscribe() объекта SDKEvents.

• **func unsubscribe(): Void** -  функция отмены передачи событий SDK(колбэк остаётся назначенным, но доставка событий прекращается). 

```swift
//отписывает от получения событий SDK 
AltcraftSDK.shared.eventSDKFunctions.unsubscribe()
```

## Работа со статусами подписки 

### изменение статуса подписки

**Функции управления статусом подписки - pushSubscribe(), pushSuspend(), pushUnSubscribe(). Выполнение подписки на пуш уведомления**

```
AltcraftSDK
// Синглтон точка входа в SDK
├─ public static let shared: AltcraftSDK
// Управление подпиской на push (изменение статуса, запросы статуса)
├─  public let pushSubscriptionFunctions: PublicPushSubscriptionFunctions
  // Оформить подписку (status = SUBSCRIBED)
  ├─ public func pushSubscribe(
  │     sync: Bool = true,
  │     profileFields: [String: Any?]? = nil,
  │     customFields: [String: Any?]? = nil,
  │     cats: [CategoryData]? = nil,
  │     replace: Bool? = nil,
  │     skipTriggers: Bool? = nil
  │   ): Void
  // Отписаться (status = UNSUBSCRIBED)
  ├─ public func pushUnSubscribe(
  │     sync: Bool = true,
  │     profileFields: [String: Any?]? = nil,
  │     customFields: [String: Any?]? = nil,
  │     cats: [CategoryData]? = nil,
  │     replace: Bool? = nil,
  │     skipTriggers: Bool? = nil
  │   ): Void
  // Приостановить (status = SUSPENDED)
  ├─ public func pushSuspend(
       sync: Bool = true,
       profileFields: [String: Any?]? = nil,
       customFields: [String: Any?]? = nil,
       cats: [CategoryData]? = nil,
       replace: Bool? = nil,
       skipTriggers: Bool? = nil
     ): Void
```

* **public func pushSubscribe()** - выполняет подписку на push-уведомления.
* **public func pushUnSubscribe()** - отменяет подписку на push-уведомления. 
* **public func pushSuspend()** - приостанавливает подписку на push уведомления.

Данные функции имеют одинаковую сигнатуру, содержащую следующие параметры:
<br><br>


#### Параметр `sync`


<br>

• `sync`: Boolean = true - флаг устанавливающий синхронность выполнения запроса (по умолчанию - синхронное). 
    
В случае успешно выполненного запроса данный группы функций (pushSubscribe, pushSuspend, pushUnSubscribe) будет создано событие с кодом = 230 содержащее значение (event.value) определяемое в зависимости от флага синхронизации: 
   
**если флаг sync == true:** 

```
ResponseWithHttpCode
  ├─ httpCode: 200
  └─ response
     ├─ error: 0
     ├─ errorText: ""
     └─ profile
        ├─ id: "your id"
        ├─ status: "subscribed"
        ├─ isTest: false
        └─ subscription
           ├─ subscriptionId: "your subscriptionId"
           ├─ hashId: "c52b28d2"
           ├─ provider: "ios-apns"
           ├─ status: "subscribed"
           ├─ fields
           │  ├─ _os_ver: {"raw":"18.6.2","ver":"[\"18.0\", \"6.0\", \"2.0\"]"}
           │  ├─ _device_type: "Mobile"
           │  ├─ _ad_track: false
           │  ├─ _device_name: "iPhone"
           │  ├─ _os_language: "en"
           │  ├─ _os_tz: "+0300"
           │  ├─ _os: "IOS"
           │  └─ _device_model: "iPhone14,7"
           └─ cats
              └─ [ { name: "developer_news", title: "dev_news", steady: false, active: false } ]
```
              
Доступ к данным в `event.value["response_with_http_code"]`  (синхронный запрос):

В значении события (`event.value`) по ключу **`"response_with_http_code"`** доступны:

* **httpCode** – транспортный код ответа.
* **Response** *(public struct)*, содержащий:

  * `error: Int?` — внутренний код ошибки сервера (*0, если ошибок нет*).
  * `errorText: String?` — текст ошибки (*пустая строка, если ошибок нет*).
  * `profile: ProfileData?` — данные профиля, если запрос успешный:

    * информация о профиле (**ProfileData**)
    * подписка (**SubscriptionData**)
    * категории подписки (**CategoryData**)
  * если запрос завершился с ошибкой → `profile = null`.

**Структуры данных:**

```swift
public struct Response {
    let error: Int?        // внутренний код ошибки
    let errorText: String? // текст ошибки
    let profile: ProfileData?
}

public struct ProfileData {
    let subscription: SubscriptionData?
    let cats: [CategoryData]?
}

public struct SubscriptionData {
    // данные о подписке
}

public struct CategoryData {
    // данные о категории подписки
}
```

**если флаг sunc = false:**

```
ResponseWithHttpCode
  ├─ httpCode: Int?
  └─ response: Response?
      ├─ error: Int?
      ├─ errorText: String?
      └─ profile: ProfileData? = nil
```

Доступ к данным в `event.value["response_with_http_code"]` (асинхронный запрос):

В значении события (`event.value`) по ключу **`"response_with_http_code"`** доступны:

* **httpCode** – транспортный код ответа.
* **Response** *(public struct)*, содержащий:

  * `error: Int?` — внутренний код ошибки сервера (*0, если ошибок нет*).
  * `errorText: String?` — текст ошибки (*пустая строка, если ошибок нет*).
  * `profile: ProfileData?` — **всегда равно `null`** для асинхронного запроса.

**Случаи ошибки:**

Если запрос данной группы функций завершился ошибкой, будет создано событие со следующими кодами:

* **430** – ошибка без автоматического повтора на стороне SDK.
* **530** – ошибка с автоматическим повтором на стороне SDK.

Содержимое события:

* только `httpCode`, если сервер Altcraft был **недоступен**;
* `error` и `errorText`, если сервер **вернул ошибку**.

Получить значения событий функций pushSubscribe, pushSuspend, pushUnSubscribe можно следующим образом: 
   
```swift
     AltcraftSDK.shared.eventSDKFunctions.subscribe { event in
            if event.eventCode == 230 {
                if let responseWithHttp = event.value?["response_with_http_code"] as? ResponseWithHttp {
                // HTTP code
                let httpCode = responseWithHttp.httpCode
                
                // Response
                let response = responseWithHttp.response
                let error = response?.error
                let errorText = response?.errorText
                
                // Profile
                let profile = response?.profile
                let profileId = profile?.id
                let profileStatus = profile?.status
                let profileIsTest = profile?.isTest
                
                // Subscription
                let subscription = profile?.subscription
                let subscriptionId = subscription?.subscriptionId
                let hashId = subscription?.hashId
                let provider = subscription?.provider
                let subscriptionStatus = subscription?.status
                
                // Fields (dictionary [String: JSONValue])
                let fields = subscription?.fields
                
                // Cats (array of CategoryData)
                let cats = subscription?.cats
                
                // CategoryData (каждый элемент массива cats)
                let firstCat = cats?.first
                let catName = firstCat?.name
                let catTitle = firstCat?.title
                let catSteady = firstCat?.steady
                let catActive = firstCat?.active
            }
        }
    }
```

Поле fields содержащиеся в subscription может содержать ваши кастомные поля подписки. Поля fields имеют тип [String: JSONValue]?. public enum JSONValue содержит вспомогательные функции позволяющие упростить получение значений fields:

```swift
    public var stringValue: String? {
        if case let .string(value) = self { return value }
        return nil
    }

    /// Returns the numeric value if case is `.number`, otherwise `nil`.
    public var numberValue: Double? {
        if case let .number(value) = self { return value }
        return nil
    }

    /// Returns the boolean value if case is `.bool`, otherwise `nil`.
    public var boolValue: Bool? {
        if case let .bool(value) = self { return value }
        return nil
    }

    /// Returns the object dictionary if case is `.object`, otherwise `nil`.
    public var objectValue: [String: JSONValue]? {
        if case let .object(value) = self { return value }
        return nil
    }

    /// Returns the array if case is `.array`, otherwise `nil`.
    public var arrayValue: [JSONValue]? {
        if case let .array(value) = self { return value }
        return nil
    }
```

Пример получения значения поля field "_device_name":

```swift
AltcraftSDK.shared.eventSDKFunctions.subscribe { event ->
    if event.eventCode == 230 {
        if let responseWithHttp = event.value?["response_with_http_code"] as? ResponseWithHttp {
            let response = responseWithHttp.response
            let profile = response?.profile
            let subscription = profile?.subscription
            
            //излекаем fields?["_device_name"] как string значение
            if let deviceName = subscription?.fields?["_device_name"]?.stringValue {
                    print(deviceName)
            }
        }     
    }
}
```
<br>


#### Параметр `profileFields` 
<br>

`[String: Any?]?` — словарь, содержащий **поля профиля**:

Параметр может принимать как **системные поля** (например, `_fname` — имя или `_lname` — фамилия), так и **опциональные** (заранее создаются вручную в интерфейсе платформы). Если передано невалидное опциональное поле, запрос завершится с ошибкой: 

```text
SDK error: 430
http code: 400
error: 400
errorText: Platform profile processing error: with field "название_поля": Incorrect field
```

* **Допустимые типы значений** (JSON-совместимые):

  * String
  * Bool
  * Числа
  * nil
  * Объекты `[String: Any]`
  * Массивы
<br>


#### Параметр `customFields`
<br>


`[String: Any?]?` — словарь, содержащий **поля подписки**:

Параметр может принимать как **системные поля** (например, `_device_model` — модель устройства или `_os` — операционная система), так и **опциональные** (заранее создаются вручную в интерфейсе платформы). Если передано невалидное опциональное поле, запрос завершится с ошибкой: 

```text
SDK error: 430
http code: 400
error: 400
errorText: Platform profile processing error: field "название_поля" is not valid: failed convert custom field
```

* **Допустимые типы значений**:

  * String
  * Bool
  * Int
  * Float
  * Double
  * nil

Вложенные объекты, массивы и коллекции **не допускаются**.

**Обратите внимание**  Большая часть системных полей подписки автоматически собирается SDK и добавляется к запросам pushSubscribe, pushSuspend, pushUnSubscribe. К ним относятся: "_os", "_os_tz", "_os_language", "_device_type", "_device_model", "_device_name", "_os_ver", "_ad_track", "_ad_id".
<br><br>


#### Параметр `cats`


<br><br>
`[CategoryData]` - категории подписок.
   
```swift
public struct CategoryData: Codable {
    public var name: String?
    public var title: String?
    public var steady: Bool?
    public var active: Bool?
}
```

При отправке запроса pushSubscribe, pushSuspend, pushUnSubscribe с указанием категорий используйте только поля name - имя категории и active - статус активности категории(активна / неактивна), другие поля не используется в обработке запроса. Поля title и steady заполняются при получении информации о подписке. 
   
Пример запроса: `let cats: [CategoryData] = [CategoryData(name: "football", title: nil, steady: nil, active: true)]`. Пример ответа: `[ { name: "developer_news", title: "dev_news", steady: false, active: false } ]`
   
Категории используемые в запросе должны быть предварительно добавлены в ресурс Altcraft платформы. Если в запросе используется поля которые не добавлены в ресурс - запрос вернется с ошибкой:

```text
SDK error: 430
http code: 400
error: 400
errorText: Platform profile processing error: field "subscriptions.cats" is not valid: category not found in resource
```
<br>
   
   
#### Параметр `replace`

`replace`: Bool? - флаг при активации которого, подписки других профилей с тем же push токеном в текущей базе данных будут переведены в статус unsubscribed после успешного выполнения запроса.

<br>

#### Параметр `skipTriggers`

`skipTriggers`: Bool? - флаг при активации которого, профиль содержащий данную подписку будет игнорироваться в триггерах. 

<br>

---

Пример выполнения запроса подписки на push уведомления: 
   
минимальная рабочая настройка - 
   
```swift
AltcraftSDK.shared.pushSubscriptionFunctions.pushSubscribe()
```
      
передача всех доступных параметров - 
  
```swift
AltcraftSDK.shared.pushSubscriptionFunctions.pushSubscribe(
    sync: true,
    profileFields: ["_fname":"Andrey", "_lname":"Pogodin"],
    customFields:  ["developer":true],
    cats: [CategoryData(name: "developer_news", active: true)],
    replace: false,
    skipTriggers:  false
)
```  
    
**Для pushSubscribe, pushSuspend, pushUnSubscribe предусмотрен автоматический повтор запроса со стороны SDK если http код ответа находится в диапазоне 500..599. Запрос не повторяется если код ответа в этот диапазон не входит**
    

• **func unSuspendPushSubscription(completion: @escaping (ResponseWithHttp?) -> Void): Void**

```swift
AltcraftSDK.shared.pushSubscriptionFunctions.unSuspendPushSubscription(completion: @escaping (ResponseWithHttp?) -> Void)
```
 
> Функцию unSuspendPushSubscription() рекомендуется применять для создания logIn, LogOut переходов. 
    
unSuspendPushSubscription работает следующим образом: 

 - поиск подписок с тем же push токеном, что и текущий, не относящихся к профилю на который указывает текущий токен JWT.
 - смена статуса для найденных подписок с subscribed на suspended
 - смена статуса в подписках профиля на который указывает текущий JWT с suspended на subscribed если профиль на который указывает JWT существует и в нем содержатся подписки. 
 - возврат public struct ResponseWithHttpCode? где response.profile - текущий профиль на который указывает JWT или nil если профиль не существует.
         

> Рекомендация реализации logIn, LogOut переходов с помощью комбинации функций unSuspendPushSubscription() и pushSubscribe(): 


* **LogIn** - Анонимный пользователь входит в приложение. Данному пользователю присвоен JWT_1 - указывающий на базу данных #1Anonymous. Выполнена подписка на push уведомления, профиль создан в базе данных #1Anonymous. Пользователь регистрируется, ему присваивается JWT_2 - указывающий на базу данных #2Registered. Вызывается функция unSuspendPushSubscription() - Подписка анонимного пользователя в базе данных #1Anonymous приостанавливается. Выполняется поиск профиля в базе данных #2Registered для восстановления подписки, но так как подписки с таким push токеном в базе данных #2Registered не существует -  функция unSuspendPushSubscription() вернет nil. После получения значения nil можно выполнить запрос на подписку pushSubscribe() - который создаст новый профиль в базе #2Registered. 

* **LogOut** -  пользователь выполнил выход из профиля на стороне приложения(LogOut) - пользователю присваивается JTW_1 - указывающий на базу данных #1Anonymous. Вызывается функция unSuspendPushSubscription() которая приостановит подписку базе данных в #2Registered, сменит статус подписки в #1Anonymous на subscribed. Вернет профиль #1Anonymous != nil - подписка существует, новая не требуется. 
  
  
> Пример реализации: 

```swift
func logIn() {
    JWTManager.shared.setRegJWT()
    //установлен JWT для авторизованного пользователя
    AltcraftSDK.shared.pushSubscriptionFunctions.unSuspendPushSubscription { result in
        if result?.httpCode == 200, result?.response?.profile?.subscription == nil {
            AltcraftSDK.shared.pushSubscriptionFunctions.pushSubscribe(
                //укажите необходимые параметры
            )
        }
    }
}

func logOut() {
    JWTManager.shared.setAnonJWT()
    //установлен JWT для анонимного пользователя
    AltcraftSDK.shared.pushSubscriptionFunctions.unSuspendPushSubscription { result in
        if result?.httpCode == 200, result?.response?.profile?.subscription == nil {
            AltcraftSDK.shared.pushSubscriptionFunctions.pushSubscribe(
                //укажите необходимые параметры
            )
        }
    }
}
```  

### запроса статуса подписки
    
Функциями запроса статуса подписки являются - `getStatusOfLatestSubscription()`, `getStatusOfLatestSubscriptionForProvider()`, `getStatusForCurrentSubscription()`

``` 
AltcraftSDK
└── static let shared: AltcraftSDK
    // Управление подпиской на push
    └── pushSubscriptionFunctions: PublicPushSubscriptionFunctions
        // Статус последней подписки профиля
        ├── getStatusOfLatestSubscription(
        │       completion: @escaping (ResponseWithHttp?) -> Void
        │   ): Void
        // Статус подписки для текущего токена/провайдера
        ├── getStatusForCurrentSubscription(
        │       completion: @escaping (ResponseWithHttp?) -> Void
        │   ): Void
        // Статус последней подписки по провайдеру (если nil — используется текущий)
        └── getStatusOfLatestSubscriptionForProvider(
                provider: String? = nil,
                completion: @escaping (ResponseWithHttp?) -> Void
            ): Void
``` 
<br><br>
• **func getStatusOfLatestSubscription(completion: @escaping (ResponseWithHttp?) -> Void): Void** - в completion передаётся объект ResponseWithHttp?, содержащий response?.profile?.subscription (последнюю созданную подписку в профиле), если такая подписка существует, иначе nil.

```swift
// Статус последней подписки профиля
AltcraftSDK.shared.pushSubscriptionFunctions.getStatusOfLatestSubscription(completion: @escaping (ResponseWithHttp?) -> Void)
```
<br><br>
• **public func getStatusForCurrentSubscription(completion: @escaping (ResponseWithHttp?) -> Void): Void** - в completion передаётся объект ResponseWithHttp?, содержащий response?.profile?.subscription — подписку, найденную по текущему push-токену и провайдеру, если такая подписка существует, иначе nil.

```swift
// Статус подписки, соответствующий текущему токену/провайдеру
AltcraftSDK.shared.pushSubscriptionFunctions.getStatusForCurrentSubscription(completion: @escaping (ResponseWithHttp?) -> Void)
```
<br><br>
• **getStatusOfLatestSubscriptionForProvider(provider: String? = nil, completion: @escaping (ResponseWithHttp?) -> Void): Void** - в completion передаётся объект ResponseWithHttp?, содержащий response?.profile?.subscription — последнюю созданную подписку с указанным провайдером push-уведомлений. Если провайдер не указан, используется провайдер текущего токена. В completion передаётся если такая подписка не существует.

```swift
// Статус последней подписки по провайдеру (если nil — используется текущий)
AltcraftSDK.shared.pushSubscriptionFunctions.getStatusOfLatestSubscriptionForProvider(provider: String? = nil, completion: @escaping (ResponseWithHttp?) -> Void)
``` 

<br>

Пример извлечения данных профиля, подписки, категорий из ответа функций получения статуса (данный подход актуален для всех функций получения статуса): 
 
```swift
AltcraftSDK.shared.pushSubscriptionFunctions.getStatusForCurrentSubscription{ responseWithHttp in
    // HTTP code
    let httpCode = responseWithHttp?.httpCode
            
    // Response
    let response = responseWithHttp?.response
    let error = response?.error
    let errorText = response?.errorText
            
    // Profile
    let profile = response?.profile
    let profileId = profile?.id
    let profileStatus = profile?.status
    let profileIsTest = profile?.isTest
            
    // Subscription
    let subscription = profile?.subscription
    let subscriptionId = subscription?.subscriptionId
    let hashId = subscription?.hashId
    let provider = subscription?.provider
    let subscriptionStatus = subscription?.status
            
    // Fields (dictionary [String: JSONValue])
    let fields = subscription?.fields
            
    // Cats (array of CategoryData)
    let cats = subscription?.cats
            
    // CategoryData (каждый элемент массива cats)
    let firstCat = cats?.first
    let catName = firstCat?.name
    let catTitle = firstCat?.title
    let catSteady = firstCat?.steady
    let catActive = firstCat?.active
}
```      

В случае успешно выполненного запроса данный группы функций (getStatusOfLatestSubscription, getStatusForCurrentSubscription, getStatusOfLatestSubscriptionForProvider) будет создано событие с кодом 234. В случае ошибки - 434.

<br>

• **public func actionField(key: String) -> ActionFieldBuilder** - передача функциональных полей профиля.

```swift
// Передача функциональных полей профиля
AltcraftSDK.shared.pushSubscriptionFunctions.actionField(key: String): ActionFieldBuilder
```

Функция actionField(key: String) является вспомогательной функцией облегчающей [процесс функционального обновления полей профиля](https://guides.altcraft.com/developer-guide/profiles/3113720/). 

пример применения: 

```swift
AltcraftSDK.shared.pushSubscriptionFunctions.pushSubscribe(
    profileFields: AltcraftSDK.shared.pushSubscriptionFunctions.actionField(key: "_fname").set(value: "Andrey")
)
```  
    
где "_fname" - поле к которому будет применяться изменение, .set("Andrey") - команда которая установит новое значение "Andrey" для этого поля. 
    
поддерживает следующие команды:
    
```swift
    .set(value)
    .unset(value)
    .incr(value)
    .add(value)
    .delete(value)
    .upsert(value)
```  
    
### Работа с пуш провайдерами. Функции объекта pushTokenFunctions 

```
AltcraftSDK
└── public static let shared: AltcraftSDK // синглтон, точка входа
    |
    // Управление push-токенами и провайдерами (FCM / HMS / APNs)
    └── public let pushTokenFunction: PublicPushTokenFunctions
        
        // Сохранить токен вручную (String для FCM/HMS, Data для APNs)
        ├── public func setPushToken(provider: String, pushToken: Any?): Void

        // Асинхронно получить текущий push-токен (completion опционален)
        ├── public func getPushToken(completion: ((TokenData?) -> Void)? = nil): Void

        // Установить провайдера Firebase Cloud Messaging (nil — снять)
        ├── public func setFCMTokenProvider(_ provider: FCMInterface?): Void

        // Установить провайдера Huawei Mobile Services (nil — снять)
        ├── public func setHMSTokenProvider(_ provider: HMSInterface?): Void

        // Установить провайдера Apple Push Notification service (nil — снять)
        ├── public func setAPNSTokenProvider(_ provider: APNSInterface?): Void

        // Применить новый приоритет провайдеров и инициировать обновление токена
        ├── public func changePushProviderPriorityList(_ list: [String]): Void

        // Удалить токен выбранного провайдера и вызвать completion
        ├── public func deleteDeviceToken(provider: String, completion: @escaping () -> Void): Void

        // Форсировать обновление токена (определить провайдера → удалить (кроме APNs) → запросить новый)
        └── public func forcedTokenUpdate(completion: (() -> Void)? = nil): Void
```

<br>

• **public func setPushToken(provider: String, pushToken: Any?): Void** - функция предназначена для ручной установки push токена устройства и провайдера в UserDefaults SDK. Используется как упрощенный вариант передачи пуш токена в SDK без реализации интерфейсов провайдеров. 
**Этот подход не рекомендуется. Рекомендуемый подход передачи push токена в SDK - реализация FCMInterface, HMSInterface, APNSInterface**

```
// Сохранить токен вручную (String для FCM/HMS, Data для APNs)
AltcraftSDK.shared.pushTokenFunction.setPushToken(provider: String, pushToken: Any?)
```

<br>

• **public func getPushToken(completion: ((TokenData?) -> Void)? = nil): Void** - в completion передаётся объект TokenData(provider: String, token: String), содержащий текущий push-токен устройства и его провайдера. Если push-токен недоступен, в completion будет передано nil.. 
 
```swift
// Асинхронно получить текущий push-токен (completion опционален)
AltcraftSDK.shared.pushTokenFunction.getPushToken(completion: ((TokenData?) -> Void)? = nil)
```

<br>

пример запроса получения данных push токена:

```swift
AltcraftSDK.shared.pushTokenFunction.getPushToken{ data in
    let provider = data?.provider
    let token = data?.token
}
``` 
  
<br>

• **public func setFCMTokenProvider(_ provider: FCMInterface?): Void** - устанавливает или снимает провайдера FCM-токена. Передайте реализацию FCMInterface (или null, чтобы отключить).
Важно: вызывайте setFCMTokenProvider() в AppDelegate.application(_:didFinishLaunchingWithOptions:)  до вызова AltcraftSDK.initialization(...). Это гарантирует регистрацию на старте процесса приложения, независимо от состояния жизненного цикла других компонентов и того, запущено приложение в foreground или background.

```swift
// Установить провайдера Firebase Cloud Messaging (nil — снять)
AltcraftSDK.shared.pushTokenFunction.setFCMTokenProvider(_ provider: FCMInterface?)
```
  
<br>

• **public func setHMSTokenProvider(_ provider: HMSInterface?): Void**  — устанавливает или снимает провайдера HMS-токена. Передайте реализацию HMSInterface (или null, чтобы отключить).
Важно: вызывайте setHMSTokenProvider() в AppDelegate.application(_:didFinishLaunchingWithOptions:) до вызова AltcraftSDK.shared.initialization(...). Это гарантирует регистрацию на старте процесса приложения, независимо от состояния жизненного цикла других компонентов и того, запущено приложение в foreground или background.  

```swift
// Установить провайдера Huawei Mobile Services (nil — снять)
AltcraftSDK.shared.pushTokenFunction.setHMSTokenProvider(_ provider: HMSInterface?)
```

<br>

• **public func setAPNSTokenProvider(_ provider: APNSInterface?): Void**  — устанавливает или снимает провайдера APNS-токена. Передайте реализацию RustoreInterface (или null, чтобы отключить).
Важно: вызывайте setAPNSTokenProvider() в AppDelegate.application(_:didFinishLaunchingWithOptions:), до вызова AltcraftSDK.initialization(...). Это гарантирует регистрацию на старте процесса приложения, независимо от состояния жизненного цикла других компонентов и того, запущено приложение в foreground или background.

```swift
// Установить провайдера Apple Push Notification service (nil — снять)
AltcraftSDK.shared.pushTokenFunction.setAPNSTokenProvider(_ provider: APNSInterface?)
```
 
Рекомендованный способ регистрации провайдеров в AppDelegate.application(_:didFinishLaunchingWithOptions:): 
 
```swift
class AppDelegate: UIResponder, UIApplicationDelegate, MessagingDelegate, UNUserNotificationCenterDelegate {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {
        let appGroup = "your appGroup id"
        
        AltcraftSDK.shared.setAppGroup(groupName: appGroup)
        AltcraftSDK.shared.backgroundTasks.registerBackgroundTask()
        AltcraftSDK.shared.setJWTProvider(provider: JWTProvider())
       
        //apns provider
        AltcraftSDK.shared.pushTokenFunction.setAPNSTokenProvider(APNSProvider())
        
        //fcm provider
        AltcraftSDK.shared.pushTokenFunction.setFCMTokenProvider(FCMProvider())
        
        //hms provider
        AltcraftSDK.shared.pushTokenFunction.setHMSTokenProvider(HMSProvider())
        
        AltcraftSDK.shared.notificationManager.registerForPushNotifications(for: application)
        
        let config = AltcraftConfiguration.Builder().setApiUrl("your api url").build()
        AltcraftSDK.shared.initialization(configuration: config)
        
        //остальные функции
        
        return true
    }
```

<br>

• **public func changePushProviderPriorityList(_ list: [String]): Void** - функция позволяющая выполнить динамическую смену провайдера push уведомлений с обновлением токена подписки. Для этого необходимо передать новый массив с другим парядком провайдеров (например: [Constants.ProviderName.firebase, Constants.ProviderName.apns, Constants.ProviderName.huawei])

```swift
// Применить новый приоритет провайдеров и инициировать обновление токена
AltcraftSDK.shared.pushTokenFunction.changePushProviderPriorityList(_ list: [String])
```

<br>

• **public func deleteDeviceToken(provider: String, completion: @escaping () -> Void): Void** - функция удаления push токена для указанного провайдера, он инвалидируется и удаляется из локального кеша на устройстве и сервере провайдера push уведомлений. После удаления можно запросить новый. 

```swift
// Удалить push-токен указанного провайдера (инвалидируется локально и на сервере)
AltcraftSDK.shared.pushTokenFunction.deleteDeviceToken(provider: String, completion: @escaping () -> Void)
```

<br>

• **public func forcedTokenUpdate(completion: (() -> Void)? = nil): Void** - функция удаления текущего push токена с последующим обновлением. 

```swift
// Форсировать обновление токена (определить провайдера → удалить (кроме APNs) → запросить новый -> обновить)
AltcraftSDK.shared.pushTokenFunction.forcedTokenUpdate(completion: (() -> Void)? = nil)
```

### Функции объекта PublicPushEventFunctions. 

```
AltcraftSDK
└── public static let shared: AltcraftSDK  
    // Синглтон, точка входа в SDK
        
        // Ручная отправка push-событий (delivery / open)
    └── public let pushEventFunctions: PublicPushEventFunctions
       
        // Зафиксировать доставку Altcraft-push (вызывает delivery-ивент)
        ├── public func deliveryEvent(from request: UNNotificationRequest): Void

        // Зафиксировать открытие Altcraft-push (вызывает open-ивент)
        └── public func openEvent(from request: UNNotificationRequest): Void
```

<br>

• **public func deliveryEvent(from request: UNNotificationRequest): Void** - функция ручной регистрации события доставки уведомления Altcraft - передайте UNNotificationRequest в параметр request для регистрации события доставки на сервере. 

```swift
// Зафиксировать доставку Altcraft-push (вызывает delivery-ивент)
AltcraftSDK.shared.pushEventFunctions.deliveryEvent(from: UNNotificationRequest)
```

<br>
• **public func openEvent(from request: UNNotificationRequest): Void** - функция ручной регистрации события открытия уведомления Altcraft - передайте UNNotificationRequest в параметр request для регистрации события доставки на сервере. 

```swift
// Зафиксировать открытие Altcraft-push (вызывает open-ивент)
AltcraftSDK.shared.pushEventFunctions.openEvent(from: UNNotificationRequest)
```

### Передача push уведомления в SDK. Класс AltcraftPushReceiver 

SDK содержит класс и функции, позволяющие принять, обработать, показать push уведомление. 

AltcraftPushReceiver — публичный класс SDK для обработки входящих push-уведомлений. Он проверяет, относится ли уведомление к Altcraft, обрабатывает содержимое (включая rich-контент) и формирует итоговое уведомление для отображения пользователю.

```
// Используется в Notification Service Extension (NSE) - обработка rich-пушей (категории/кнопки/медиа), без зависимостей на UIApplication
AltcraftPushReceiver       
// Проверить, что пуш — от Altcraft (по маркеру в userInfo)
├─ public func isAltcraftPush(_ request: UNNotificationRequest) -> Bool
// Обработать входящий запрос: создать категории/кнопки, прикрепить медиа, зафиксировать delivery и отдать контент в NSE
├─ public func didReceive(_ request: UNNotificationRequest, withContentHandler contentHandler: @escaping (UNNotificationContent) -> Void): Void
// Вернуть "best attempt" контент при таймауте NSE
└─ public func serviceExtensionTimeWillExpire(): Void
```

<br>

• **public func isAltcraftPush(_ request: UNNotificationRequest) -> Bool** - функция SDK выполняющая проверку то что уведомление - это уведомление Altcraft.

```swift
// Проверить, что пуш — от Altcraft (по маркеру в userInfo)
AltcraftPushReceiver().isAltcraftPush(_ request: UNNotificationRequest) -> Bool
```

<br>

• **public func didReceive(_ request: UNNotificationRequest, withContentHandler contentHandler: @escaping (UNNotificationContent) -> Void): Void** - функция SDK принимающая UNNotificationRequest из Notification Service Extension (NSE)  для его дальнейшей обработки на стороне SDK и показа уведомлений. 

```swift
// Обработать входящий запрос: создать категории/кнопки, прикрепить медиа, зафиксировать delivery и отдать контент в NSE
AltcraftPushReceiver().didReceive(_ request: UNNotificationRequest, withContentHandler contentHandler: @escaping (UNNotificationContent) -> Void)
```

<br>

• **public func serviceExtensionTimeWillExpire()** – вызывается системой при истечении времени работы Notification Service Extension (~30 секунд)

```swift
// Вернуть "best attempt" контент при таймауте NSE
AltcraftPushReceiver().serviceExtensionTimeWillExpire()
```

## Очистка данных SDK

SDK содержит функцию clear() позволяющую выполнить очиску данных SDK и отменить работу всех, ожидающих выполнения, фоновых задач.

```
AltcraftSDK
// Синглтон точка входа в SDK
├─ public static let shared: AltcraftSDK
// Полная очистка данных SDK (кэш/БД/настройки), затем вызов completion
├─ public func clear(completion: (() -> Void)? = nil): Void
```

<br><br>
• **public func clear(completion: (() -> Void)? = nil): Void** - удаляет записи CoreData, очищает UserDefaults.

```swift
// Полная очистка данных SDK (кэш/БД/настройки), затем вызов completion
AltcraftSDK.shared. clear(completion: (() -> Void)? = nil)
```

Функция принимает необязательный параметр completion, который вызывается после завершения очистки и отмены задач.


## Публичные функции и классы SDK

**class AltcraftSDK** 
  
```
AltcraftSDK
// Синглтон точка входа в SDK
├─ public static let shared: AltcraftSDK
// Инициализация SDK конфигурацией (completion вызывается на main)
├─ public func initialization(configuration: AltcraftConfiguration?, completion: ((Bool) -> Void)? = nil): Void
// Установка App Group и инициализация Core Data под shared-контейнер
├─ public func setAppGroup(groupName: String): Void
// Регистрация JWT-провайдера для получения токенов
├─ public func setJWTProvider(provider: JWTInterface): Void
// Полная очистка данных SDK (кэш/БД/настройки), затем вызов completion
├─ public func clear(completion: (() -> Void)? = nil): Void
| 
// Поток SDK-событий (один активный подписчик)
├─ public let eventSDKFunctions: SDKEvents
│  // Подписаться на события SDK (заменяет существующего подписчика)
│  ├─ func subscribe(callback: @escaping (Event) -> Void): Void
│  // Отписаться от событий (колбэк остаётся назначенным, доставка останавливается)
│  ├─ func unsubscribe(): Void
│  // Модель события (базовый тип для всех событий/ошибок)
│  ├─ Event
│  │   // Базовая модель события
│  │   id: UUID
│  │   function: String
│  │   message: String?
│  │   eventCode: Int?
│  │   value: [String: Any?]?
│  │   date: Date
│  │   // Конструктор (нормализация function, фильтрация nil в value)
│  │   init(function: String, message: String? = nil, eventCode: Int? = nil, value: [String: Any?]? = nil, date: Date = Date())
│  │   // Сравнение по уникальному id
│  │   static func ==(lhs: Event, rhs: Event) -> Bool
│  │   // Хеширование по id
│  │   func hash(into hasher: inout Hasher): Void
│  │
│  │   // Ошибки без повторов (4xx-класс)
│  │   ErrorEvent : Event
│  │   init(function: String, message: String? = nil, eventCode: Int? = nil, value: [String: Any?]? = nil, date: Date = Date())
│  │
│  │   // Повторяемые ошибки (обычно 5xx)
│  │   RetryEvent : ErrorEvent
│  │   init(function: String, message: String? = nil, eventCode: Int? = 0, value: [String: Any?]? = nil, date: Date = Date())
| 
// Управление push-токенами и провайдерами (FCM/HMS/APNs)
├─  public let pushTokenFunction: PublicPushTokenFunctions
│  // Установить провайдера Firebase Cloud Messaging (nil — снять)
│  ├─ public func setFCMTokenProvider(_ provider: FCMInterface?): Void
│  // Установить провайдера Huawei Mobile Services (nil — снять)
│  ├─ public func setHMSTokenProvider(_ provider: HMSInterface?): Void
│  // Установить провайдера Apple Push Notification service (nil — снять)
│  ├─ public func setAPNSTokenProvider(_ provider: APNSInterface?): Void
│  // Асинхронно получить текущий push-токен (completion опционален)
│  ├─ public func getPushToken(completion: ((TokenData?) -> Void)? = nil): Void
│  // Сохранить токен вручную (String для FCM/HMS, Data для APNs); provider: "ios-firebase" | "ios-huawei" | "ios-apns"
│  ├─ public func setPushToken(provider: String, pushToken: Any?): Void
│  // Применить новый приоритет провайдеров и инициировать обновление токена
│  ├─ public func changePushProviderPriorityList(_ list: [String]): Void
│  // Удалить токен выбранного провайдера и вызвать completion
│  ├─ public func deleteDeviceToken(provider: String, completion: @escaping () -> Void): Void
│  // Форсировать обновление токена (определить провайдера → удалить (кроме APNs) → запросить новый)
│  └─ public func forcedTokenUpdate(completion: (() -> Void)? = nil): Void
| 
// Управление подпиской на push (изменение статуса, запросы статуса)
├─  public let pushSubscriptionFunctions: PublicPushSubscriptionFunctions
│  // Оформить подписку (status = SUBSCRIBED)
│  ├─ public func pushSubscribe(
│  │     sync: Bool = true,
│  │     profileFields: [String: Any?]? = nil,
│  │     customFields: [String: Any?]? = nil,
│  │     cats: [CategoryData]? = nil,
│  │     replace: Bool? = nil,
│  │     skipTriggers: Bool? = nil
│  │   ): Void
│  // Отписаться (status = UNSUBSCRIBED)
│  ├─ public func pushUnSubscribe(
│  │     sync: Bool = true,
│  │     profileFields: [String: Any?]? = nil,
│  │     customFields: [String: Any?]? = nil,
│  │     cats: [CategoryData]? = nil,
│  │     replace: Bool? = nil,
│  │     skipTriggers: Bool? = nil
│  │   ): Void
│  // Приостановить (status = SUSPENDED)
│  ├─ public func pushSuspend(
│  │     sync: Bool = true,
│  │     profileFields: [String: Any?]? = nil,
│  │     customFields: [String: Any?]? = nil,
│  │     cats: [CategoryData]? = nil,
│  │     replace: Bool? = nil,
│  │     skipTriggers: Bool? = nil
│  │   ): Void
│  // UnSuspend подписки (один запрос, без ретраев/персиста)
│  ├─ public func unSuspendPushSubscription(
│  │     completion: @escaping (ResponseWithHttp?) -> Void
│  │   ): Void
│  // Статус последней подписки профиля
│  ├─ public func getStatusOfLatestSubscription(
│  │     completion: @escaping (ResponseWithHttp?) -> Void
│  │   ): Void
│  // Статус подписки, соответствующий текущим токену/провайдеру
│  ├─ public func getStatusForCurrentSubscription(
│  │     completion: @escaping (ResponseWithHttp?) -> Void
│  │   ): Void
│  // Статус последней подписки по провайдеру (если nil — используется текущий)
│  └─ public func getStatusOfLatestSubscriptionForProvider(
│  │       provider: String? = nil,
│  │       completion: @escaping (ResponseWithHttp?) -> Void
│  │     ): Void
|   // добавить функциональное поле профиля(set/incr/...)
|  └─ public func actionField(key: String) -> ActionFieldBuilder
| 
// ручная отправка пуш-событий (delivery/open)
├─  public let  pushEventFunctions: PublicPushEventFunctions
│  // Зафиксировать доставку Altcraft-push (вызывает delivery-ивент)
│  ├─ public func deliveryEvent(from request: UNNotificationRequest): Void
│  // Зафиксировать открытие Altcraft-push (вызывает open-ивент)
│  └─ public func openEvent(from request: UNNotificationRequest): Void
| 
// Регистрация периодических фоновых задач (BGAppRefreshTask)
├─ public let backgroundTasks: BackgroundTasks
│  // Зарегистрировать задачу и запланировать периодический запуск (~каждые 3 часа)
│  └─ public func registerBackgroundTask(): Void
| 
// Управление нотификациями в приложении (делегат центра уведомлений)
├─  public let notificationManager: NotificationManager
   // Назначить делегата, запросить разрешения и зарегистрироваться на remote notifications; completion вернёт granted/error
   ├─ func registerForPushNotifications(for application: UIApplication, completion: ((_ granted: Bool, _ error: Error?) -> Void)? = nil): Void
   // Показ уведомлений в форграунде (баннер/алерт + бейдж/звук)
   ├─ public func userNotificationCenter(
   │     _ center: UNUserNotificationCenter,
   │     willPresent notification: UNNotification,
   │     withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
   │   ): Void
   // Обработка взаимодействия пользователя (клик/действия), логирование open-ивента
   └─ public func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
      ): Void
``` 
 
**class AltcraftPushReceiver**
   
```
// Используется в Notification Service Extension (NSE) - обработка rich-пушей (категории/кнопки/медиа), без зависимостей на UIApplication
AltcraftPushReceiver       
// Проверить, что пуш — от Altcraft (по маркеру в userInfo)
├─ public func isAltcraftPush(_ request: UNNotificationRequest) -> Bool
// Обработать входящий запрос: создать категории/кнопки, прикрепить медиа, зафиксировать delivery и отдать контент в NSE
├─ public func didReceive(_ request: UNNotificationRequest, withContentHandler contentHandler: @escaping (UNNotificationContent) -> Void): Void
// Вернуть "лучший доступный" контент при таймауте NSE
└─ public func serviceExtensionTimeWillExpire(): Void
```

**class AltcraftConfiguration**

```
AltcraftConfiguration
// Класс конфигурации Altcraft SDK.
// Хранит базовый API URL и опциональные параметры (rToken, AppInfo, providerPriorityList).
// Создаётся только через Builder.
│ 
├─ public class Builder
│  // Builder для формирования конфигурации с валидацией.
│  // Позволяет задать обязательные и опциональные поля и собрать объект конфигурации.
│  // Конструктор билдера
│  ├─ public init(): Builder
│  // Задать API URL (обязательный параметр)
│  ├─ public func setApiUrl(_ url: String) -> Builder
│  // Задать ресурсный токен (опционально)
│  ├─ func setRToken(_ rToken: String?) -> Builder
│  // Задать метаданные приложения AppInfo используемые в Firebase Analytis
│  ├─ public public func setAppInfo(_ info: AppInfo?) -> Builder
│  // Задать приоритет провайдеров пуш-уведомлений (опционально)
│  ├─ public func setProviderPriorityList(_ list: [String]?) -> Builder
│  // Построить валидную конфигурацию (nil, если валидация не пройдена)
│  └─ public func build() -> AltcraftConfiguration?
// Доступ к параметрам конфигурации
├─ public func getApiUrl() -> String
├─ public func getRToken() -> String?
├─ public func getAppInfo() -> AppInfo?
└─ public func getProviderPriorityList() -> [String]?
```


**публичные структуры** 

```
TokenData
// структура для хранения push-токена и имя провайдера (для UserDefaults).
provider: String  // "ios-apns", "ios-firebase", "ios-huawei"
token: String

AppInfo
//Представляет базовые метаданные приложения, используемые в Firebase Analytics.
appID: String
appIID: String
appVer: String
├─ init(appID: String, appIID: String, appVer: String)

// Обёртка ответа API вместе с HTTP-кодом.
ResponseWithHttp
httpCode: Int?
response: Response?

// Ответ синхронного запроса на изменения и получения статуса подписок.
Response
error: Int?
errorText: String?      
profile: ProfileData?

// Данные профиля пользователя.
ProfileData
id: String?
status: String?
isTest: Bool?           
subscription: SubscriptionData?

// Текущая подписка профиля.
SubscriptionData
subscriptionId: String? 
hashId: String?         
provider: String?
status: String?
fields: [String: JSONValue]?
cats: [CategoryData]?

// Описание категории подписки.
CategoryData
name: String?
title: String?
steady: Bool?
active: Bool?
├─ init(name: String?, title: String?, steady: Bool?, active: Bool?)

// Универсальное JSON-значение для произвольных полей.
JSONValue (enum)
cases:
  - string(String)
  - number(Double)
  - bool(Bool)
  - object([String: JSONValue])
  - array([JSONValue])
  - null
// Conformance: Codable (кастомное кодирование/декодирование).
```


