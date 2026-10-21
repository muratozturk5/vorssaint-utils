// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import Foundation

struct ClipboardSyncStrings {
    let enable: String
    let content: String
    let textOnly: String
    let textAndImages: String
    let caption: String
    let privacyNote: String
    /// Replace the history's "stays on this Mac" caption and note while
    /// sync is on.
    let historyCaption: String
    let localNote: String
    let checking: String
    let noICloudDrive: String
    let unreachable: String
    let syncedFormat: String
    let otherMacsFormat: String
}

extension FeatureStrings {
    static func clipboardSync(_ language: AppLanguage) -> ClipboardSyncStrings {
        switch language {
        case .enUS: return .enUS
        case .ptBR: return .ptBR
        case .tr: return .tr
        case .ru: return .ru
        case .es: return .es
        case .sk: return .sk
        case .de: return .de
        case .fr: return .fr
        case .it: return .it
        case .ja: return .ja
        case .ko: return .ko
        case .zhHans: return .zhHans
        case .zhTW: return .zhTW
        case .zhHK: return .zhHK
        case .uk: return .uk
        }
    }
}

extension ClipboardSyncStrings {
    static let enUS = ClipboardSyncStrings(
        enable: "Sync history with your other Macs through iCloud",
        content: "Sync",
        textOnly: "Text only",
        textAndImages: "Text and images",
        caption: "Items copied on this Mac also show up on your other Macs signed in to the same Apple Account, through a Vorssaint folder in your iCloud Drive. Deleting or clearing items removes them on every Mac. Anything the history skips is never synced, and copied files and very large items stay on this Mac.",
        privacyNote: "Synced items are stored as files in your iCloud Drive and protected like the rest of it. Turning sync off removes this Mac’s copy there; your other Macs keep what they already received.",
        historyCaption: "Stores copied text so you can reuse it later, on this Mac and your other Macs. It can be cleared anytime.",
        localNote: "Saved items are also copied to your iCloud Drive while sync is on. Very large items are ignored.",
        checking: "Checking iCloud Drive…",
        noICloudDrive: "iCloud Drive is off on this Mac. Turn it on in System Settings to sync.",
        unreachable: "Vorssaint can’t reach its folder in iCloud Drive. If macOS asked, allow access to iCloud Drive.",
        syncedFormat: "Last synced at %@",
        otherMacsFormat: "Other Macs: %d"
    )

    static let ptBR = ClipboardSyncStrings(
        enable: "Sincronizar o histórico com seus outros Macs pelo iCloud",
        content: "Sincronizar",
        textOnly: "Só texto",
        textAndImages: "Texto e imagens",
        caption: "Itens copiados neste Mac também aparecem nos seus outros Macs conectados à mesma Conta Apple, por meio de uma pasta do Vorssaint no seu iCloud Drive. Apagar ou limpar itens os remove de todos os Macs. Nada que o histórico ignora é sincronizado, e arquivos copiados e itens muito grandes ficam neste Mac.",
        privacyNote: "Os itens sincronizados ficam guardados como arquivos no seu iCloud Drive, protegidos como o restante dele. Desativar a sincronização remove a cópia deste Mac de lá; seus outros Macs mantêm o que já receberam.",
        historyCaption: "Guarda textos copiados para reutilizar depois, neste Mac e nos seus outros Macs. Pode ser apagado a qualquer momento.",
        localNote: "Os itens guardados também vão para o seu iCloud Drive enquanto a sincronização está ativada. Itens muito grandes são ignorados.",
        checking: "Verificando o iCloud Drive…",
        noICloudDrive: "O iCloud Drive está desativado neste Mac. Ative-o nos Ajustes do Sistema para sincronizar.",
        unreachable: "O Vorssaint não consegue acessar a pasta dele no iCloud Drive. Se o macOS perguntar, permita o acesso ao iCloud Drive.",
        syncedFormat: "Última sincronização às %@",
        otherMacsFormat: "Outros Macs: %d"
    )

    static let tr = ClipboardSyncStrings(
        enable: "Geçmişi iCloud ile diğer Mac’lerinizle eşzamanla",
        content: "Eşzamanla",
        textOnly: "Yalnızca metin",
        textAndImages: "Metin ve görseller",
        caption: "Bu Mac’te kopyalanan öğeler, iCloud Drive’ınızdaki bir Vorssaint klasörü aracılığıyla aynı Apple Hesabı’yla giriş yapılmış diğer Mac’lerinizde de görünür. Öğeleri silmek ya da temizlemek onları her Mac’ten kaldırır. Geçmişin atladığı hiçbir şey eşzamanlanmaz; kopyalanan dosyalar ve çok büyük öğeler bu Mac’te kalır.",
        privacyNote: "Eşzamanlanan öğeler iCloud Drive’ınızda dosya olarak saklanır ve oradaki her şey gibi korunur. Eşzamanlamayı kapatmak bu Mac’in oradaki kopyasını kaldırır; diğer Mac’leriniz aldıklarını saklar.",
        historyCaption: "Kopyalanan metinleri daha sonra yeniden kullanabilmeniz için bu Mac’te ve diğer Mac’lerinizde saklar. İstediğiniz zaman temizlenebilir.",
        localNote: "Eşzamanlama açıkken kaydedilen öğeler iCloud Drive’ınıza da kopyalanır. Çok büyük öğeler yok sayılır.",
        checking: "iCloud Drive denetleniyor…",
        noICloudDrive: "Bu Mac’te iCloud Drive kapalı. Eşzamanlamak için Sistem Ayarları’ndan açın.",
        unreachable: "Vorssaint, iCloud Drive’daki klasörüne ulaşamıyor. macOS sorduysa iCloud Drive erişimine izin verin.",
        syncedFormat: "Son eşzamanlama: %@",
        otherMacsFormat: "Diğer Mac’ler: %d"
    )

    static let ru = ClipboardSyncStrings(
        enable: "Синхронизировать историю с другими Mac через iCloud",
        content: "Синхронизировать",
        textOnly: "Только текст",
        textAndImages: "Текст и изображения",
        caption: "Элементы, скопированные на этом Mac, появляются и на других ваших Mac с тем же Аккаунтом Apple через папку Vorssaint в вашем iCloud Drive. Удаление или очистка элементов убирает их на всех Mac. То, что история пропускает, никогда не синхронизируется, а скопированные файлы и очень большие элементы остаются на этом Mac.",
        privacyNote: "Синхронизированные элементы хранятся в виде файлов в вашем iCloud Drive и защищены так же, как всё остальное в нём. Если выключить синхронизацию, копия этого Mac будет удалена оттуда; другие Mac сохранят то, что уже получили.",
        historyCaption: "Сохраняет скопированный текст на этом Mac и других ваших Mac, чтобы вы могли использовать его позже. Его можно очистить в любой момент.",
        localNote: "Пока синхронизация включена, сохранённые элементы также копируются в ваш iCloud Drive. Слишком большие элементы игнорируются.",
        checking: "Проверка iCloud Drive…",
        noICloudDrive: "iCloud Drive выключен на этом Mac. Включите его в Системных настройках, чтобы синхронизировать.",
        unreachable: "Vorssaint не может открыть свою папку в iCloud Drive. Если macOS спросит, разрешите доступ к iCloud Drive.",
        syncedFormat: "Последняя синхронизация: %@",
        otherMacsFormat: "Других Mac: %d"
    )

    static let es = ClipboardSyncStrings(
        enable: "Sincronizar el historial con tus otros Mac a través de iCloud",
        content: "Sincronizar",
        textOnly: "Solo texto",
        textAndImages: "Texto e imágenes",
        caption: "Los elementos copiados en este Mac también aparecen en tus otros Mac con la misma cuenta de Apple, a través de una carpeta de Vorssaint en tu iCloud Drive. Al eliminar o borrar elementos, desaparecen de todos los Mac. Nada de lo que el historial omite se sincroniza, y los archivos copiados y los elementos muy grandes se quedan en este Mac.",
        privacyNote: "Los elementos sincronizados se guardan como archivos en tu iCloud Drive, protegidos como el resto de su contenido. Al desactivar la sincronización se elimina de allí la copia de este Mac; tus otros Mac conservan lo que ya recibieron.",
        historyCaption: "Guarda el texto copiado para reutilizarlo después, en este Mac y en tus otros Mac. Se puede borrar cuando quieras.",
        localNote: "Mientras la sincronización está activada, los elementos guardados también se copian en tu iCloud Drive. Los elementos muy grandes se ignoran.",
        checking: "Comprobando iCloud Drive…",
        noICloudDrive: "iCloud Drive está desactivado en este Mac. Actívalo en Ajustes del Sistema para sincronizar.",
        unreachable: "Vorssaint no puede acceder a su carpeta en iCloud Drive. Si macOS lo pide, permite el acceso a iCloud Drive.",
        syncedFormat: "Última sincronización a las %@",
        otherMacsFormat: "Otros Mac: %d"
    )

    static let sk = ClipboardSyncStrings(
        enable: "Synchronizovať históriu s ostatnými Macmi cez iCloud",
        content: "Synchronizovať",
        textOnly: "Iba text",
        textAndImages: "Text a obrázky",
        caption: "Položky skopírované na tomto Macu sa cez priečinok Vorssaint vo vašom iCloud Drive zobrazia aj na vašich ďalších Macoch prihlásených do rovnakého Apple účtu. Vymazanie alebo vyčistenie položiek ich odstráni na každom Macu. Nič, čo história vynecháva, sa nesynchronizuje a skopírované súbory a príliš veľké položky zostávajú na tomto Macu.",
        privacyNote: "Synchronizované položky sa ukladajú ako súbory vo vašom iCloud Drive a sú chránené ako všetko ostatné v ňom. Vypnutím synchronizácie sa odtiaľ odstráni kópia tohto Macu; ostatné Macy si ponechajú, čo už dostali.",
        historyCaption: "Ukladá skopírovaný text, aby ste ho mohli neskôr znova použiť na tomto Macu aj na ďalších Macoch. Môžete ho kedykoľvek vymazať.",
        localNote: "Kým je synchronizácia zapnutá, uložené položky sa kopírujú aj do vášho iCloud Drive. Príliš veľké položky sa ignorujú.",
        checking: "Kontroluje sa iCloud Drive…",
        noICloudDrive: "iCloud Drive je na tomto Macu vypnutý. Na synchronizáciu ho zapnite v Systémových nastaveniach.",
        unreachable: "Vorssaint sa nedostane k svojmu priečinku v iCloud Drive. Ak sa macOS opýta, povoľte prístup k iCloud Drive.",
        syncedFormat: "Naposledy synchronizované o %@",
        otherMacsFormat: "Ďalšie Macy: %d"
    )

    static let de = ClipboardSyncStrings(
        enable: "Verlauf über iCloud mit deinen anderen Macs synchronisieren",
        content: "Synchronisieren",
        textOnly: "Nur Text",
        textAndImages: "Text und Bilder",
        caption: "Auf diesem Mac kopierte Einträge erscheinen über einen Vorssaint-Ordner in deinem iCloud Drive auch auf deinen anderen Macs mit demselben Apple Account. Gelöschte oder geleerte Einträge verschwinden auf jedem Mac. Was der Verlauf auslässt, wird nie synchronisiert, und kopierte Dateien sowie sehr große Einträge bleiben auf diesem Mac.",
        privacyNote: "Synchronisierte Einträge liegen als Dateien in deinem iCloud Drive und sind geschützt wie alles andere dort. Wenn du die Synchronisierung ausschaltest, wird die Kopie dieses Macs dort entfernt; deine anderen Macs behalten, was sie schon erhalten haben.",
        historyCaption: "Speichert kopierten Text, damit du ihn später auf diesem Mac und deinen anderen Macs wiederverwenden kannst. Er kann jederzeit gelöscht werden.",
        localNote: "Solange die Synchronisierung an ist, werden gespeicherte Einträge auch in dein iCloud Drive kopiert. Sehr große Inhalte werden ignoriert.",
        checking: "iCloud Drive wird geprüft…",
        noICloudDrive: "iCloud Drive ist auf diesem Mac aus. Schalte es in den Systemeinstellungen ein, um zu synchronisieren.",
        unreachable: "Vorssaint erreicht seinen Ordner in iCloud Drive nicht. Falls macOS fragt, erlaube den Zugriff auf iCloud Drive.",
        syncedFormat: "Zuletzt synchronisiert um %@",
        otherMacsFormat: "Andere Macs: %d"
    )

    static let fr = ClipboardSyncStrings(
        enable: "Synchroniser l’historique avec vos autres Mac via iCloud",
        content: "Synchroniser",
        textOnly: "Texte uniquement",
        textAndImages: "Texte et images",
        caption: "Les éléments copiés sur ce Mac apparaissent aussi sur vos autres Mac connectés au même compte Apple, grâce à un dossier Vorssaint dans votre iCloud Drive. Supprimer ou effacer des éléments les retire de chaque Mac. Rien de ce que l’historique ignore n’est synchronisé, et les fichiers copiés ainsi que les éléments très volumineux restent sur ce Mac.",
        privacyNote: "Les éléments synchronisés sont stockés sous forme de fichiers dans votre iCloud Drive et protégés comme le reste de son contenu. Désactiver la synchronisation y supprime la copie de ce Mac. Vos autres Mac conservent ce qu’ils ont déjà reçu.",
        historyCaption: "Enregistre le texte copié pour le réutiliser plus tard, sur ce Mac et vos autres Mac. Il peut être effacé à tout moment.",
        localNote: "Tant que la synchronisation est activée, les éléments enregistrés sont aussi copiés dans votre iCloud Drive. Les éléments très volumineux sont ignorés.",
        checking: "Vérification d’iCloud Drive…",
        noICloudDrive: "iCloud Drive est désactivé sur ce Mac. Activez-le dans Réglages Système pour synchroniser.",
        unreachable: "Vorssaint ne peut pas accéder à son dossier dans iCloud Drive. Si macOS le demande, autorisez l’accès à iCloud Drive.",
        syncedFormat: "Dernière synchronisation à %@",
        otherMacsFormat: "Autres Mac\u{00A0}: %d"
    )

    static let it = ClipboardSyncStrings(
        enable: "Sincronizza la cronologia con gli altri Mac tramite iCloud",
        content: "Sincronizza",
        textOnly: "Solo testo",
        textAndImages: "Testo e immagini",
        caption: "Gli elementi copiati su questo Mac compaiono anche sugli altri Mac collegati allo stesso Account Apple, tramite una cartella Vorssaint nel tuo iCloud Drive. Eliminare o svuotare gli elementi li rimuove da ogni Mac. Nulla di ciò che la cronologia esclude viene sincronizzato, e i file copiati e gli elementi molto grandi restano su questo Mac.",
        privacyNote: "Gli elementi sincronizzati sono salvati come file nel tuo iCloud Drive e protetti come il resto del suo contenuto. Disattivando la sincronizzazione, la copia di questo Mac viene rimossa da lì; gli altri Mac conservano ciò che hanno già ricevuto.",
        historyCaption: "Salva il testo copiato per riutilizzarlo in seguito, su questo Mac e sugli altri tuoi Mac. Può essere cancellato in qualsiasi momento.",
        localNote: "Finché la sincronizzazione è attiva, gli elementi salvati vengono copiati anche nel tuo iCloud Drive. Gli elementi molto grandi vengono ignorati.",
        checking: "Controllo di iCloud Drive…",
        noICloudDrive: "iCloud Drive è disattivato su questo Mac. Attivalo in Impostazioni di Sistema per sincronizzare.",
        unreachable: "Vorssaint non riesce a raggiungere la sua cartella in iCloud Drive. Se macOS lo chiede, consenti l’accesso a iCloud Drive.",
        syncedFormat: "Ultima sincronizzazione alle %@",
        otherMacsFormat: "Altri Mac: %d"
    )

    static let ja = ClipboardSyncStrings(
        enable: "iCloudでほかのMacと履歴を同期",
        content: "同期する内容",
        textOnly: "テキストのみ",
        textAndImages: "テキストと画像",
        caption: "このMacでコピーした項目は、iCloud DriveのVorssaintフォルダを通じて、同じApple AccountでサインインしているほかのMacにも表示されます。項目を削除または消去すると、すべてのMacから取り除かれます。履歴が除外するものは同期されず、コピーしたファイルや大きすぎる項目はこのMacに残ります。",
        privacyNote: "同期された項目はiCloud Driveにファイルとして保存され、ほかの内容と同じように保護されます。同期をオフにすると、このMacのコピーはそこから削除されます。ほかのMacは受け取った項目を保持します。",
        historyCaption: "コピーしたテキストを保存して、このMacとほかのMacであとで再利用できます。いつでも削除できます。",
        localNote: "同期がオンの間、保存した項目はiCloud Driveにもコピーされます。大きすぎる項目は無視されます。",
        checking: "iCloud Driveを確認中…",
        noICloudDrive: "このMacではiCloud Driveがオフです。同期するにはシステム設定でオンにしてください。",
        unreachable: "VorssaintがiCloud Drive内のフォルダにアクセスできません。macOSに尋ねられた場合は、iCloud Driveへのアクセスを許可してください。",
        syncedFormat: "最終同期: %@",
        otherMacsFormat: "ほかのMac: %d台"
    )

    static let ko = ClipboardSyncStrings(
        enable: "iCloud로 다른 Mac과 기록 동기화",
        content: "동기화 항목",
        textOnly: "텍스트만",
        textAndImages: "텍스트 및 이미지",
        caption: "이 Mac에서 복사한 항목이 iCloud Drive의 Vorssaint 폴더를 통해 같은 Apple 계정으로 로그인한 다른 Mac에도 표시됩니다. 항목을 삭제하거나 지우면 모든 Mac에서 제거됩니다. 기록이 건너뛰는 항목은 동기화되지 않으며, 복사한 파일과 너무 큰 항목은 이 Mac에 남습니다.",
        privacyNote: "동기화된 항목은 iCloud Drive에 파일로 저장되며 다른 내용과 같은 방식으로 보호됩니다. 동기화를 끄면 이 Mac의 사본이 그곳에서 제거되며, 다른 Mac은 이미 받은 항목을 유지합니다.",
        historyCaption: "복사한 텍스트를 저장하여 이 Mac과 다른 Mac에서 나중에 다시 사용할 수 있습니다. 언제든 지울 수 있습니다.",
        localNote: "동기화가 켜져 있는 동안 저장된 항목이 iCloud Drive에도 복사됩니다. 너무 큰 항목은 무시됩니다.",
        checking: "iCloud Drive 확인 중…",
        noICloudDrive: "이 Mac에서 iCloud Drive가 꺼져 있습니다. 동기화하려면 시스템 설정에서 켜십시오.",
        unreachable: "Vorssaint가 iCloud Drive의 폴더에 접근할 수 없습니다. macOS가 묻는 경우 iCloud Drive 접근을 허용하십시오.",
        syncedFormat: "마지막 동기화: %@",
        otherMacsFormat: "다른 Mac: %d대"
    )

    static let zhHans = ClipboardSyncStrings(
        enable: "通过 iCloud 与你的其他 Mac 同步历史",
        content: "同步内容",
        textOnly: "仅文本",
        textAndImages: "文本和图片",
        caption: "在这台 Mac 上拷贝的项目会通过你 iCloud 云盘中的 Vorssaint 文件夹，同样出现在登录同一 Apple 账户的其他 Mac 上。删除或清除项目会在每台 Mac 上移除它们。历史记录跳过的内容永远不会同步，拷贝的文件和特别大的项目会留在这台 Mac 上。",
        privacyNote: "同步的项目以文件形式存储在你的 iCloud 云盘中，并像其中的其他内容一样受到保护。关闭同步会移除这台 Mac 在那里的副本，你的其他 Mac 会保留已经收到的内容。",
        historyCaption: "保存拷贝的文本，以便稍后在这台 Mac 和你的其他 Mac 上重复使用。可以随时清除。",
        localNote: "开启同步时，保存的项目也会拷贝到你的 iCloud 云盘。特别大的内容会被忽略。",
        checking: "正在检查 iCloud 云盘…",
        noICloudDrive: "这台 Mac 上的 iCloud 云盘已关闭。请在系统设置中打开它以进行同步。",
        unreachable: "Vorssaint 无法访问它在 iCloud 云盘中的文件夹。如果 macOS 询问，请允许访问 iCloud 云盘。",
        syncedFormat: "上次同步：%@",
        otherMacsFormat: "其他 Mac：%d 台"
    )

    static let zhTW = ClipboardSyncStrings(
        enable: "透過 iCloud 與你的其他 Mac 同步紀錄",
        content: "同步內容",
        textOnly: "僅文字",
        textAndImages: "文字和圖片",
        caption: "在這台 Mac 上拷貝的項目會透過你 iCloud 雲碟中的 Vorssaint 檔案夾，同樣顯示在登入相同 Apple 帳號的其他 Mac 上。刪除或清除項目會在每台 Mac 上移除它們。紀錄略過的內容永遠不會同步，拷貝的檔案和過大的項目會留在這台 Mac 上。",
        privacyNote: "同步的項目會以檔案形式儲存在你的 iCloud 雲碟中，並像其中的其他內容一樣受到保護。關閉同步會移除這台 Mac 在那裡的副本，你的其他 Mac 會保留已經收到的內容。",
        historyCaption: "儲存拷貝的文字，以便稍後在這台 Mac 和你的其他 Mac 上重複使用。可以隨時清除。",
        localNote: "開啟同步時，儲存的項目也會拷貝到你的 iCloud 雲碟。過大的內容會被略過。",
        checking: "正在檢查 iCloud 雲碟…",
        noICloudDrive: "這台 Mac 上的 iCloud 雲碟已關閉。請在系統設定中開啟以進行同步。",
        unreachable: "Vorssaint 無法取用它在 iCloud 雲碟中的檔案夾。如果 macOS 詢問，請允許取用 iCloud 雲碟。",
        syncedFormat: "上次同步：%@",
        otherMacsFormat: "其他 Mac：%d 台"
    )

    static let zhHK = ClipboardSyncStrings(
        enable: "透過 iCloud 與你的其他 Mac 同步記錄",
        content: "同步內容",
        textOnly: "只限文字",
        textAndImages: "文字和圖片",
        caption: "在這部 Mac 上拷貝的項目會透過你 iCloud 雲碟中的 Vorssaint 檔案夾，同樣顯示在登入相同 Apple 帳户的其他 Mac 上。刪除或清除項目會在每部 Mac 上移除它們。記錄略過的內容永遠不會同步，拷貝的檔案和過大的項目會留在這部 Mac 上。",
        privacyNote: "同步的項目會以檔案形式儲存在你的 iCloud 雲碟中，並像其中的其他內容一樣受到保護。關閉同步會移除這部 Mac 在那裡的副本，你的其他 Mac 會保留已經收到的內容。",
        historyCaption: "儲存拷貝的文字，以便稍後在這部 Mac 和你的其他 Mac 上重複使用。可以隨時清除。",
        localNote: "開啟同步時，儲存的項目亦會拷貝到你的 iCloud 雲碟。過大的內容會被略過。",
        checking: "正在檢查 iCloud 雲碟…",
        noICloudDrive: "這部 Mac 上的 iCloud 雲碟已關閉。請在系統設定中開啟以進行同步。",
        unreachable: "Vorssaint 無法取用它在 iCloud 雲碟中的檔案夾。如果 macOS 詢問，請允許取用 iCloud 雲碟。",
        syncedFormat: "上次同步：%@",
        otherMacsFormat: "其他 Mac：%d 部"
    )

    static let uk = ClipboardSyncStrings(
        enable: "Синхронізувати історію з іншими Mac через iCloud",
        content: "Синхронізувати",
        textOnly: "Лише текст",
        textAndImages: "Текст і зображення",
        caption: "Елементи, скопійовані на цьому Mac, з’являються й на інших ваших Mac з тим самим обліковим записом Apple через папку Vorssaint у вашому iCloud Drive. Видалення або очищення елементів прибирає їх на всіх Mac. Те, що історія пропускає, ніколи не синхронізується, а скопійовані файли й дуже великі елементи залишаються на цьому Mac.",
        privacyNote: "Синхронізовані елементи зберігаються як файли у вашому iCloud Drive і захищені так само, як усе інше в ньому. Вимкнення синхронізації видаляє звідти копію цього Mac; інші Mac зберігають те, що вже отримали.",
        historyCaption: "Зберігає скопійований текст на цьому Mac та інших ваших Mac, щоб ви могли використати його пізніше. Його можна очистити будь-коли.",
        localNote: "Поки синхронізацію ввімкнено, збережені елементи також копіюються у ваш iCloud Drive. Надто великі елементи ігноруються.",
        checking: "Перевірка iCloud Drive…",
        noICloudDrive: "iCloud Drive вимкнено на цьому Mac. Увімкніть його в Системних параметрах, щоб синхронізувати.",
        unreachable: "Vorssaint не може відкрити свою папку в iCloud Drive. Якщо macOS запитає, дозвольте доступ до iCloud Drive.",
        syncedFormat: "Остання синхронізація: %@",
        otherMacsFormat: "Інших Mac: %d"
    )
}
