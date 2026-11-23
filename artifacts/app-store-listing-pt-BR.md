# Punctual - App Store listing (v1.0.5, Brazilian Portuguese / pt-BR)

Version 1.0.5 adds Brazilian Portuguese to the app UI (de, fr, es and pt-BR). Translated by Claude,
**not checked by a native speaker**: get one pass from a native speaker before relying on it beyond a
first test. UI words quoted here match the pt-BR UI translation (`pt-BR-1/2/3.json`): Pular hoje,
Tocar mesmo assim, Acordei, “Já acordou?”, alerta prévio, Toca em, Adiar, Parar.

Rules (App Review 2.3.7): no price, no discount and no "gratuito/grátis" in the name, subtitle,
keywords, promo or captions ("gratuito" only in the description). No other platform names.

Character limits: name 30 · subtitle 30 · promo 170 · keywords 100 · description 4000.
Counts measured with Python `len()`, as App Store Connect does. Keywords in UTF-8 bytes (`len(s.encode())`).

## App Name (28/30)
Punctual: Alarme Despertador

## Subtitle (30/30)
Pula feriado, toca em dia útil

<!-- 1.0.5 (16 Nov 2026), was "Pule folgas, feriados, plantão". Same change as en-US: holidays skipped, workdays
     keep ringing, no shift promise (plantão). -->

## Promotional Text (164/170)
Veja a contagem regressiva de cada alarme, receba um alerta prévio antes de tocar e pule só hoje com um toque – o de amanhã continua ativo. Com o AlarmKit da Apple.

## Keywords (99/100)
acordar,turno,folga,emenda,feriadão,carnaval,férias,viagem,soneca,lembrete,manhã,trabalho,dormir

<!-- No word repeats the name or subtitle (punctual, alarme, despertador, pular, feriado, tocar, dia, útil).
     Picks: acordar (to wake up), turno (the one shift word; "alarme turno" is searched), folga (moved here from the subtitle in 1.0.5,
     replacing escala), emenda + feriadão (bridge days
     and long weekends), carnaval (a "ponto facultativo" many people have off), férias, viagem, soneca (the everyday word;
     the UI uses Apple's "Adiar"), lembrete, manhã, trabalho, dormir. Singular forms only;
     accents are kept since the App Store matches accented and unaccented spellings. -->

## Description (3934/4000)
O Punctual é o alarme inteligente que o Relógio da Apple nunca chegou a ser. Veja exatamente quando o alarme toca, receba um alerta prévio antes e pule só um dia – o de amanhã continua programado.

O PROBLEMA DE TODO APP DE ALARME
O iOS só consegue pular um alarme: o de despertar do seu Horário de Sono. Em todos os outros, uma folga, um feriadão ou um plantão trocado deixam uma única opção: desativar o alarme e torcer para lembrar de ativá-lo de novo. O Punctual dá a todos os alarmes o tratamento que a Apple reservou para um só.

PULAR HOJE, SEM ESQUECER AMANHÃ
Um toque pula apenas o toque de hoje. O alarme continua ativo para amanhã, você vê a confirmação em verde – “Não vai tocar hoje – continua ativo” – e ainda pode desfazer se mudar de ideia. Pule pelo cartão do alarme, pela notificação de alerta prévio ou direto da Tela Bloqueada.

SAIBA SEMPRE QUANDO TOCA
Cada alarme mostra uma contagem regressiva ao vivo – “Toca em 7h 42m” – atualizada em tempo real, até enquanto você escolhe o horário. Chega de fazer conta de madrugada.

UM ALERTA PRÉVIO ANTES DE TOCAR
Uma notificação discreta antes de cada alarme, com um botão Pular na própria notificação. Decida do travesseiro, antes de o alarme começar a tocar.

TOCA NO MODO SILENCIOSO E COM FOCO ATIVADO
Criado com o AlarmKit da Apple, o Punctual toca exatamente como o app Relógio nativo – no modo silencioso e com um Foco ativado.

GRATUITO PARA SEMPRE
A experiência essencial – alarmes ilimitados, contagem regressiva ao vivo, alerta prévio, Pular hoje e adiamento com a duração que você escolher, até 15 minutos – é gratuita. Sem anúncios. Sem conta. Sem rastreamento. Tudo fica no seu dispositivo.

PUNCTUAL PRO – PARA QUANDO VOCÊ QUISER MAIS
• Pausa nas férias: silencie os alarmes por um período; eles voltam a tocar sozinhos
• Tempo de alerta prévio personalizado, vários alertas prévios e suas próprias mensagens
• Adiamento mais longo: até 60 minutos, além do limite de 15 minutos do sistema
• Verificação “Já acordou?”: 5 minutos depois de você parar um alarme, uma notificação discreta pergunta se você já acordou. Toque em “Acordei” ou o alarme toca mais uma vez.
• Grupos de alarmes: pule ou pause um conjunto inteiro de uma vez
• Pulo automático pelo calendário: eventos de dia inteiro nos calendários que você escolher (feriados, folgas) pulam o alarme – com um aviso na véspera e um botão “Tocar mesmo assim”
• Temas, cores de destaque e ícones alternativos do app
• Sons personalizados: importe seu próprio áudio para o alerta prévio e o alarme

Pague como preferir: mensal, anual ou uma compra única Vitalícia. Se você não gosta de assinaturas, o plano Vitalício é seu para sempre. Sem aluguel por um despertador.

PRIVADO POR NATUREZA
Sem contas, sem análises, sem rastreamento. Seus alarmes nunca saem do seu dispositivo.

UM AVISO HONESTO SOBRE CONFIABILIDADE
Nenhum app de alarme pode garantir que vai tocar – quem decide, em última instância, quando os alarmes disparam é o iOS, e um iPhone desligado ou sem bateria não consegue tocar de forma alguma. Para qualquer compromisso que você não pode perder, programe um segundo alarme independente.

Requer iOS 26 ou posterior (o Punctual é criado com o framework AlarmKit da Apple).

DETALHES DA ASSINATURA
O Punctual Pro está disponível como assinatura mensal ou anual com renovação automática, ou como compra única Vitalícia. O pagamento é cobrado na sua Conta Apple na confirmação. As assinaturas são renovadas automaticamente, a menos que a renovação automática seja desativada pelo menos 24 horas antes do fim do período atual; você pode gerenciar ou cancelar a qualquer momento nos ajustes da sua Conta Apple. Os preços atuais são exibidos no app antes da compra.

Termos de Uso: https://punctualalarm.com/terms.html
Política de Privacidade: https://punctualalarm.com/privacy.html
Suporte e FAQ: https://punctualalarm.com/support.html

Dúvidas? contact@arinitsolutions.com · punctualalarm.com

## What's New (v1.0.6)
• A contagem regressiva dos widgets da Tela de Início e da Tela Bloqueada agora se atualiza ao vivo, minuto a minuto, sem abrir o app. Depois que um alarme toca, o widget passa sozinho para o próximo.
• Na Tela Bloqueada, o widget mostra a hora, a etiqueta e a contagem regressiva cada uma em sua linha, para que tudo caiba.
• Pequenas correções e melhorias.

## What's New (v1.0.5)
• O Punctual agora está disponível em português do Brasil.
• Novo no Pro: a verificação “Já acordou?”. 5 minutos depois de você tocar em Parar, uma notificação discreta pergunta se você já acordou. Toque em “Acordei” ou o alarme toca mais uma vez, 2 minutos depois.

## Screenshot captions (pt-BR)
Slice 1: "Pule hoje,
sem esquecer amanhã" + sub "O alarme que avisa antes de tocar."
Slice 3: "Saiba sempre
quando toca" + sub "Contagem regressiva ao vivo em cada alarme.
“Toca em 6h 47m”
se atualiza em tempo real."
Slice 4: "Configure em segundos"
Slice 5: "Temas, ícones do app
e padrões,
do seu jeito."
Slice 6: "Um toque pula
hoje ou
amanhã."
Slice 7: "Passe para o Pro
quando quiser" + sub "Pausa nas férias, grupos de alarmes,
alertas prévios personalizados,
temas e seus próprios sons."
