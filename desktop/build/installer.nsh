; Удаление CivCity: вместе с программой убираем и скачанную ею игру (папки game* в данных программы, ~300 МБ).
; Сохранения (saves) и вход (launcher.json) остаются — после переустановки город и вход на месте.
; При обновлении поверх (isUpdated) ничего не трогаем.
!macro customUnInstall
  ${ifNot} ${isUpdated}
    ${if} $installMode == "all"
      SetShellVarContext current
    ${endif}
    RMDir /r "$APPDATA\CivCity\game"
    RMDir /r "$APPDATA\CivCity\game-new"
    RMDir /r "$APPDATA\CivCity\game-old"
    RMDir /r "$APPDATA\CivCity\game-dl"
  ${endIf}
!macroend
