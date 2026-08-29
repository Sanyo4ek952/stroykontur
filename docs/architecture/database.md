# PWA строительного объекта — логическая модель данных

**Файл:** `docs/architecture/database.md`  
**Версия:** 0.2  
**Основание:** `domain-model.md` + `workflows.md` + `roles-permissions.md`  
**Статус:** Logical Data Model  
**Важно:** документ не содержит физическую SQL-схему.

---

# 1. Цель документа

Документ определяет:

- логические сущности;
- cardinality между сущностями;
- обязательность связей;
- уникальность бизнес-данных;
- принадлежность данных строительному объекту;
- правила tenant/project isolation;
- lifecycle-зависимости;
- где нужны snapshot-данные;
- какие связи нельзя дублировать.

Физическая реализация:

- таблицы;
- PK/FK;
- SQL-типы;
- enums;
- indexes;
- RLS;
- triggers;
- migrations

будет определена отдельно после утверждения этой модели.

---

# 2. Основной принцип изоляции

Главная единица бизнес-изоляции:

`Project`

Почти каждая операционная сущность должна принадлежать конкретному Project напрямую либо однозначно через родительскую сущность.

## Правило

Пользователь не должен получить доступ к данным другого объекта только потому, что:

- знает ID сущности;
- имеет такую же роль на другом объекте;
- использует прямой API-запрос;
- вручную изменил URL.

UI не является границей безопасности.

---

# 3. Типы связей

Используются обозначения:

- `1:1` — один к одному;
- `1:N` — один ко многим;
- `N:M` — многие ко многим;
- `0..1` — связь необязательна;
- `1..N` — минимум один элемент.

---

# 4A. Organization & Project participation

## 4A.1. Organization

Каноническая организация. Не принадлежит одному Project и может участвовать в нескольких объектах.

`Organization N:M Project` через `ProjectOrganization`.

`Organization N:M User` через `OrganizationMember`.

`Organization 1:N Employee`.

`Organization 0..1:1 Counterparty` — коммерческий профиль организации при необходимости.

## 4A.2. OrganizationMember

Устойчивая принадлежность User к Organization, не заменяет ProjectMember.

Рекомендуемая активная уникальность: `organization + user`.

## 4A.3. ProjectOrganization

`Project N:M Organization`.

Хранит тип участия (заказчик, генподрядчик, подрядчик, субподрядчик, проектировщик, лаборатория, поставщик и др.), статус и период участия.

Операционный ProjectMember обязан иметь ProjectOrganization context.

---

# 4. Project Context

## 4.1. Project

### Назначение

Корневая сущность строительного объекта.

### Связи

`Project 1:N ProjectArea`

`Project 1:N ProjectMember`

`Project 1:N TechnicalDocument`

`Project 1:N Work`

`Project 1:N SupplyRequest`

`Project 1:N Contract`

`Project 1:N EmployeeProjectAssignment`

`Project 1:N Task`

`Project 1:N Event`

`Project 1:N AuditEntry`

### Уникальность

Внутренний код/номер объекта должен быть уникален в пределах организации, если такой код используется.

### Lifecycle

Удаление Project не должно каскадно уничтожать бизнес-историю.

Используется архивирование.

---

## 4.2. ProjectArea

### Назначение

Иерархическая физическая зона объекта.

### Связи

`Project 1:N ProjectArea`

`ProjectArea 0..1 : N ProjectArea`

Родительская и дочерние зоны.

### Примеры

```text
Объект
└── Корпус
    └── Захватка
        └── Этаж
            └── Ось/конструкция
```

### Правила

- ProjectArea всегда принадлежит одному Project;
- parent ProjectArea должен принадлежать тому же Project;
- циклическая иерархия запрещена.

### Уникальность

Название не обязано быть глобально уникальным.

Рекомендуется уникальность комбинации:

`project + parent area + area code/name`

если это соответствует реальному процессу.

---

# 5. Identity, Membership & Authorization

## 5.1. User

### Назначение

Учётная запись приложения.

### Связи

`User 1:N ProjectMember`

`User 0..1 : 1 Employee`

Связь с Employee необязательна.

### Уникальность

- auth identity;
- email/телефон — согласно выбранной auth-модели.

---

## 5.2. ProjectMember

### Назначение

Членство пользователя в конкретном Project.

### Связи

`Project N:M User` через `ProjectMember`

`ProjectMember N:1 ProjectOrganization` — обязательный организационный контекст операционного участника.

`ProjectMember N:M Role`

или один primary Role + дополнительные роли — решение physical model.

`ProjectMember N:M ProjectArea`

если доступ ограничен зонами.

### Обязательность

Каждый ProjectMember должен иметь:

- Project;
- User;
- ProjectOrganization;
- статус участия;
- минимум одну роль или явно заданный профиль доступа.

### Уникальность

`Project + User` — уникальная активная membership-запись.

История участия может храниться отдельно.

---

## 5.3. Role

### Назначение

Бизнес-роль.

### Связи

`Role N:M Permission`

`ProjectMember N:M Role`

### Уникальность

Системный role key уникален.

Пример:

`site_manager`

---

## 5.4. Permission

### Назначение

Атомарное полномочие.

### Связи

`Role N:M Permission`

### Уникальность

Permission key глобально уникален.

Пример:

`quality.work.accept`

---

## 5.5. ResponsibilityAssignment

### Назначение

Исторически отслеживаемое назначение ответственного.

### Связи

Одна ResponsibilityAssignment относится к:

- Project;
- ProjectMember/User;
- конкретному responsibility target.

Target может быть:

- Work;
- ProjectArea;
- Process;
- TechnicalDocument;
- другой разрешённый доменный объект.

### Cardinality

Один объект может иметь несколько назначений во времени.

### Правило

Для одной ответственности в один момент времени может существовать только одно активное основное назначение, если процесс не допускает нескольких ответственных.

---

# 6. Technical Documentation

## 6.1. TechnicalDocument

### Связи

`Project 1:N TechnicalDocument`

`TechnicalDocument 1:N DocumentRevision`

`TechnicalDocument N:M Work`

через конкретные применимые ревизии/выдачи в производство.

### Уникальность

В пределах Project логический номер документа должен быть уникален с учётом принятой схемы нумерации.

---

## 6.2. DocumentRevision

### Связи

`TechnicalDocument 1:N DocumentRevision`

`DocumentRevision 1:N DocumentFile`

`DocumentRevision 1:N DocumentIssueForWork`

`DocumentRevision 1:N DocumentImpact`

### Уникальность

В пределах одного TechnicalDocument номер ревизии уникален.

Например:

`document_id + revision_code`

---

## 6.3. DocumentFile

### Связи

`DocumentRevision 1:N DocumentFile`

### Назначение

Физические представления документа:

- PDF;
- DWG;
- XLSX.

### Правило

DocumentFile не существует без DocumentRevision.

---

## 6.4. DocumentIssueForWork

### Назначение

Факт выдачи ревизии в производство.

### Связи

`DocumentRevision 1:N DocumentIssueForWork`

`DocumentIssueForWork N:M ProjectArea`

`DocumentIssueForWork N:M Work`

если выдача ограничена конкретными работами.

### Правила

Для одной области применения одновременно не должно существовать двух конфликтующих активных ревизий одного документа.

---

## 6.5. DocumentImpact

### Связи

`DocumentRevision 1:N DocumentImpact`

`DocumentImpact N:1 Work`

`DocumentImpact 0..1:N ProjectArea`

`DocumentImpact 1:N Task`

в случае необходимости действий.

### Правило

DocumentImpact фиксирует анализ влияния и не заменяет сам Work.

---

# 7. Production

## 7.1. Work

### Связи

`Project 1:N Work`

`ProjectArea 1:N Work`

или Work может быть связан с несколькими зонами через отдельную mapping-сущность, если это понадобится.

`Work 1:N WorkProgressEntry`

`Work 1:N WorkAssignment`

`Work 1:N WorkRequirement`

`Work N:M Work` через WorkDependency

`Work 1:N ProductionIssue`

`Work 1:N InspectionRequest`

`Work 1:N ExecutivePackage`

`Work 1:N MaterialRequirement`

`Work 1:N AcceptedWorkVolume`

### Обязательные связи

Минимально:

- Project;
- ProjectArea;
- тип/наименование работы;
- единица измерения;
- responsible owner после перевода в READY.

### Уникальность

Название Work не обязано быть уникальным.

Для устойчивой идентификации лучше использовать системный ID + бизнес-код при необходимости.

---

## 7.2. WorkDependency

### Связи

`Work N:M Work`

через:

- predecessor;
- successor;
- dependency type.

### Правила

- Work не может зависеть сам от себя;
- циклы должны быть запрещены либо обнаруживаться системой.

---

## 7.3. WorkRequirement

### Связи

`Work 1:N WorkRequirement`

Requirement может ссылаться на:

- DocumentRevision;
- MaterialRequirement;
- WorkAdmission rule;
- WorkPermit;
- predecessor Work;
- Inspection/quality gate.

### Правило

BLOCKING requirement должен влиять на допустимый переход Work.

---

## 7.4. WorkAssignment

### Связи

`Work 1:N WorkAssignment`

`Employee 1:N WorkAssignment`

`ProjectMember 0..1:N WorkAssignment`

### Назначение

Кто фактически назначен на работу.

### Правило

Employee и Work должны относиться к одному Project-контексту через назначение сотрудника на объект.

---

## 7.5. WorkProgressEntry

### Связи

`Work 1:N WorkProgressEntry`

`DailyReport 0..1:N WorkProgressEntry`

`ProjectMember/User 1:N WorkProgressEntry`

как автор.

### Правила

- подтверждённая запись immutable;
- исправление создаёт correction relation;
- quantity не может быть отрицательной без специального correction workflow.

---

## 7.6. DailyReport

### Связи

`Project 1:N DailyReport`

`DailyReport 1:N WorkProgressEntry`

`DailyReport N:M Employee`

через shift/crew assignment.

### Уникальность

В зависимости от процесса:

`Project + date + responsible/site area`

может быть уникальным.

Точное правило определить при physical schema.

---

## 7.7. ProductionIssue

### Связи

`Work 1:N ProductionIssue`

`ProductionIssue 0..N Task`

`ProductionIssue 0..1 DocumentImpact`

`ProductionIssue 0..1 SupplyRequest`

при связанной причине.

### Правило

Issue должен иметь severity.

---

# 8. Materials & Supply

## 8.1. Material

### Связи

`Material 1:N MaterialRequirement`

`Material 1:N SupplyRequestItem`

`Material 1:N MaterialBatch`

### Уникальность

Каталожный код материала уникален, если используется master catalog.

---

## 8.2. MaterialRequirement

### Связи

`Work 1:N MaterialRequirement`

`Material 1:N MaterialRequirement`

`MaterialRequirement 0..N SupplyRequestItem`

### Назначение

Потребность Work в материале.

### Правило

SupplyRequest не должна быть единственным местом, где существует производственная потребность.

---

## 8.3. SupplyRequest

### Связи

`Project 1:N SupplyRequest`

`SupplyRequest 1:N SupplyRequestItem`

`SupplyRequest 0..N Approval`

`SupplyRequest 0..N Task`

### Обязательность

SupplyRequest должна иметь инициатора.

---

## 8.4. SupplyRequestItem

### Связи

`SupplyRequest 1:N SupplyRequestItem`

`SupplyRequestItem N:1 Material`

`SupplyRequestItem 0..1:N MaterialRequirement`

### Правило

Одна позиция заявки не должна ссылаться на material другого Project-контекста, если каталог project-specific.

---

## 8.5. Delivery

### Связи

`Project 1:N Delivery`

`Counterparty 1:N Delivery`

`Delivery 1:N MaterialBatch`

`Delivery 0..1 Contract`

`Delivery 0..N SupplyRequestItem`

### Назначение

Факт поставки.

---

## 8.6. MaterialBatch

### Связи

`Delivery 1:N MaterialBatch`

`Material 1:N MaterialBatch`

`MaterialBatch 1:N Attachment`

`MaterialBatch 0..N IncomingMaterialInspection`

`MaterialBatch 0..N MaterialMovement`

### Уникальность

Номер партии не обязан быть глобально уникальным.

Комбинация supplier/material/batch number может использоваться как бизнес-ключ.

---

## 8.7. MaterialMovement

### Связи

`MaterialBatch 1:N MaterialMovement`

`Work 0..1:N MaterialMovement`

`ProjectArea 0..1:N MaterialMovement`

### Правило

Полноценный складской контур можно отложить, но модель должна позволять его добавить.

---

# 9. Quality

## 9.1. InspectionRequest

### Связи

`Work 1:N InspectionRequest`

`InspectionRequest 0..1:1 Inspection`

### Правило

Один вызов может завершиться одной основной Inspection.

При повторной проверке создаётся новая Inspection либо новая InspectionRequest — решение physical model.

---

## 9.2. Inspection

### Связи

`Work 1:N Inspection`

`ProjectMember 1:N Inspection`

как проверяющий.

`Inspection 1:N QualityIssue`

`Inspection 0..1 QualityChecklist`

### Правило

Inspection всегда должна ссылаться на реальную Work либо MaterialBatch для incoming inspection.

---

## 9.3. QualityIssue

### Связи

`Inspection 1:N QualityIssue`

`QualityIssue 1:N Task`

`QualityIssue 0..N Attachment`

`QualityIssue 1:N AuditEntry`

### Правило

Закрытие QualityIssue требует verifying actor, если workflow это требует.

---

## 9.4. IncomingMaterialInspection

### Связи

`MaterialBatch 1:N IncomingMaterialInspection`

`ProjectMember 1:N IncomingMaterialInspection`

### Правило

Текущий статус допуска партии определяется последним валидным результатом workflow, а не вручную дублируемым boolean.

---

# 9A. Geodesy

## GeodeticTask

`Project 1:N GeodeticTask`, `Work 0..1:N GeodeticTask`, `ProjectArea 1:N GeodeticTask`.

## GeodeticSurvey

`Project 1:N GeodeticSurvey`, `GeodeticTask 1:N GeodeticSurvey`, `Work 0..1:N GeodeticSurvey`, `ProjectMember 1:N GeodeticSurvey` как исполнитель.

Повторная съёмка создаёт новый result record.

## GeodeticScheme

`GeodeticSurvey 0..N GeodeticScheme`; файлы схемы хранятся через разрешённый attachment/document mechanism.

## GeodeticInstrument

`Organization 1:N GeodeticInstrument`, `GeodeticInstrument 1:N GeodeticSurvey`. История поверок/калибровок сохраняется отдельно, если она обязательна.

## GeodeticDeviation

`GeodeticSurvey 1:N GeodeticDeviation`.

---

# 10. Executive Documentation

## 10.1. ExecutivePackage

### Связи

`Project 1:N ExecutivePackage`

`Work 1:N ExecutivePackage`

`ExecutivePackage 1:N ExecutiveRequirement`

`ExecutivePackage 1:N ExecutiveDocument`

`ExecutivePackage N:M DocumentRevision`

`ExecutivePackage N:M MaterialBatch`

`ExecutivePackage N:M Inspection`

### Правило

ExecutivePackage не копирует производственные/качественные данные без необходимости snapshot.

---

## 10.2. ExecutiveRequirement

### Связи

`ExecutivePackage 1:N ExecutiveRequirement`

### Назначение

Определяет комплектность.

### Уникальность

В одном ExecutivePackage одно обязательное требование конкретного типа не должно случайно дублироваться.

---

## 10.3. ExecutiveDocument

### Связи

`ExecutivePackage 1:N ExecutiveDocument`

`ExecutiveDocument 1:N Attachment`

### Правило

Тип документа обязателен.

Для юридически значимых документов разрешён immutable snapshot реквизитов и подписантов.

---

# 11. Counterparties & Contracts

## 11.1. Counterparty

### Связи

`Counterparty 1:N Contract`

`Counterparty 1:N Delivery`

`Counterparty 1:N Invoice`

`Counterparty 1:N Payment`

### Уникальность

Рекомендуется уникальность по официальному идентификатору организации, если он хранится.

Например:

ИНН + КПП либо иной идентификатор.

---

## 11.2. Contract

### Связи

`Project 1:N Contract`

`Counterparty 1:N Contract`

`Contract 1:N ContractItem`

`Contract 1:N Invoice`

`Contract 1:N AdditionalWorkRequest`

`Contract 0..N Attachment`

### Уникальность

Номер договора уникален в рамках контекста организации/контрагента по принятой политике.

---

## 11.3. ContractItem

### Связи

`Contract 1:N ContractItem`

`ContractItem 0..N Work`

`ContractItem 0..N Material`

`ContractItem 0..N EstimateItem`

### Назначение

Договорное основание конкретного объёма/работы/поставки.

---

# 12. Estimates & Additional Work

## 12.1. Estimate

### Связи

`Project 1:N Estimate`

`Estimate 1:N EstimateItem`

`Estimate 0..1 Contract`

---

## 12.2. EstimateItem

### Связи

`Estimate 1:N EstimateItem`

`EstimateItem 0..N Work`

`EstimateItem 0..N ContractItem`

---

## 12.3. AdditionalWorkRequest

### Связи

`Project 1:N AdditionalWorkRequest`

`AdditionalWorkRequest 0..1:N Work`

после согласования.

`AdditionalWorkRequest 0..N Approval`

`AdditionalWorkRequest 0..1 Contract`

`AdditionalWorkRequest 0..N Attachment`

### Правило

До APPROVED связанная Work не должна считаться обычной разрешённой производственной работой, кроме специального emergency workflow.

---

# 13. Commercial Closing / KS

## 13.1. AcceptedWorkVolume

### Связи

`Work 1:N AcceptedWorkVolume`

`WorkProgressEntry 1:N AcceptedWorkVolume`

`Inspection 0..N AcceptedWorkVolume`

`ExecutivePackage 0..N AcceptedWorkVolume`

`ClosingPeriod 1:N AcceptedWorkVolume`

### Ключевое правило

Сумма коммерчески закрытого объёма не может превышать подтверждённый производственный объём с учётом корректировок.

---

## 13.2. ClosingPeriod

### Связи

`Project 1:N ClosingPeriod`

`ClosingPeriod 1:N AcceptedWorkVolume`

`ClosingPeriod 0..N KS2`

`ClosingPeriod 0..N KS3`

`ClosingPeriod 0..N KS6a`

### Уникальность

Период + contract/counterparty context должен быть уникален, если процесс предусматривает одно закрытие за период.

---

## 13.3. KS2 / KS3 / KS6a

### Связи

`ClosingPeriod 1:N KS document`

`Contract 1:N KS document`

`Counterparty 1:N KS document`

`KS document N:M AcceptedWorkVolume`

### Правило

Один AcceptedWorkVolume не должен быть включён в два активных коммерческих закрытия, если это создаёт двойную оплату.

---

# 14. Finance

## 14.1. Invoice

### Связи

`Project 1:N Invoice`

`Counterparty 1:N Invoice`

`Contract 0..1:N Invoice`

`Invoice 0..N PaymentRequest`

### Уникальность

`Counterparty + invoice number + invoice date`

рекомендуется как защита от дублей.

---

## 14.2. PaymentRequest

### Связи

`Invoice 0..1:N PaymentRequest`

`PaymentRequest 0..N Approval`

`PaymentRequest 0..N Payment`

### Правило

PaymentRequest должна иметь business basis:

- Invoice;
- Contract;
- KS;
- Delivery;
- иной разрешённый тип основания.

---

## 14.3. Payment

### Связи

`Project 1:N Payment`

`Counterparty 1:N Payment`

`PaymentRequest 0..1:N Payment`

`Invoice 0..1:N Payment`

### Правило

Payment — факт, а не план.

После подтверждения payment record должен быть защищён от обычного редактирования.

---

# 15. Personnel

## 15.1. Employee

### Связи

`Employee 0..1 User`

`Employee 1:N EmployeeProjectAssignment`

`Employee 1:N SafetyCertificate`

`Employee 1:N SafetyBriefing`

`Employee 1:N TimesheetEntry`

`Employee 1:N WorkAssignment`

### Уникальность

Внутренний personnel number уникален, если используется.

Персональные идентификаторы должны иметь отдельную политику защиты.

---

## 15.2. EmployeeProjectAssignment

### Назначение

Факт допуска/назначения Employee на конкретный Project.

### Связи

`Employee 1:N EmployeeProjectAssignment`

`Project 1:N EmployeeProjectAssignment`

### Уникальность

Не более одной активной assignment-записи одного Employee на один Project, если бизнес не требует истории параллельных назначений.

---

## 15.3. EmployeePosition

### Связи

`Employee N:M EmployeePosition`

через assignment/history model.

### Правило

Должность и специальность могут отличаться.

---

## 15.4. Shift

### Связи

`Project 1:N Shift`

`Shift N:M Employee`

`Shift 0..1 DailyReport`

---

## 15.5. TimesheetEntry

### Связи

`Employee 1:N TimesheetEntry`

`Project 1:N TimesheetEntry`

`Shift 0..1:N TimesheetEntry`

### Уникальность

Нельзя создавать конфликтующие дубли рабочего времени одного Employee за тот же интервал без correction workflow.

---

# 16. Safety

## 16.1. SafetyQualification

### Связи

`SafetyQualification 1:N SafetyCertificate`

`SafetyQualification N:M WorkType/Requirement`

---

## 16.2. SafetyCertificate

### Связи

`Employee 1:N SafetyCertificate`

`SafetyQualification 1:N SafetyCertificate`

### Уникальность

Номер удостоверения может иметь уникальность в рамках типа/выдавшей организации.

---

## 16.3. SafetyBriefing

### Связи

`Employee 1:N SafetyBriefing`

`Project 1:N SafetyBriefing`

`ProjectMember/User 1:N SafetyBriefing`

как проводящий.

---

## 16.4. WorkAdmission

### Связи

`Employee 1:N WorkAdmission`

`Project 1:N WorkAdmission`

`Work 0..1:N WorkAdmission`

`SafetyCertificate N:M WorkAdmission`

`SafetyBriefing N:M WorkAdmission`

### Правило

WorkAdmission — вычисленный/подтверждённый бизнес-результат допуска, а не замена первичным сертификатам.

---

## 16.5. WorkPermit

### Связи

`Project 1:N WorkPermit`

`Work 1:N WorkPermit`

`WorkPermit N:M Employee`

`WorkPermit N:M ProjectMember`

как ответственные/выдающие.

`WorkPermit 0..N Attachment`

### Правила

- WorkPermit имеет период действия;
- нельзя считать ACTIVE после EXPIRED/CLOSED;
- изменения после ISSUE должны контролироваться workflow.

---

# 17. Access Passes

## 17.1. Visitor

### Связи

`Project 1:N Visitor`

`Visitor 1:N AccessRequest`

---

## 17.2. AccessRequest

### Связи

`Project 1:N AccessRequest`

Request target может быть:

- Employee;
- Visitor;
- Equipment;
- MaterialBatch/TMC.

`AccessRequest 0..1:1 AccessPass`

---

## 17.3. AccessPass

### Связи

`AccessRequest 1:0..1 AccessPass`

### Правило

Pass должен иметь:

- validity period;
- status;
- subject identity.

---

# 17A. Electronic Journals

## JournalTypeDefinition

Reference definition типа журнала: permissions, numbering/signoff/correction policy и обязательные связи. Может быть global/reference и не иметь project_id.

## ElectronicJournal

`Project 1:N ElectronicJournal`, `ElectronicJournal N:1 JournalTypeDefinition`, `ProjectArea 0..1:N ElectronicJournal`.

## JournalEntry

`ElectronicJournal 1:N JournalEntry`, `Project 1:N JournalEntry`. Для work-based типов: `Work 0..1:N JournalEntry`.

Уникальность номера минимум `electronic_journal + entry_number`.

## JournalEntryRevision

`JournalEntry 1:N JournalEntryRevision`, прямой `project_id` обязателен. Подтверждённая запись корректируется новой revision.

## JournalEntrySignoff

`JournalEntry 1:N JournalEntrySignoff`, `ProjectMember 1:N JournalEntrySignoff`. Signoff immutable.

---

# 18. Workflow & Collaboration

## 18.1. Task

### Связи

`Project 1:N Task`

`Task N:1 ProjectMember/User` — assignee.

`Task 0..N Event`

`Task 0..N Comment`

`Task 0..N Attachment`

Task должен ссылаться на business target.

### Business target

Логически это:

- Work;
- DocumentImpact;
- QualityIssue;
- SupplyRequest;
- ExecutivePackage;
- Approval;
- WorkPermit;
- другую разрешённую сущность.

Физическая связь с target реализуется только через разрешённые явные FK/domain link tables согласно разделу 26 и ADR-003.

---

## 18.2. Event

### Связи

`Project 1:N Event`

`Event 1:N Notification`

`Event 0..N Task`

`Event 0..N Acknowledgement`

### Правило

Event immutable.

---

## 18.3. Notification

### Связи

`Event 1:N Notification`

`User/ProjectMember 1:N Notification`

### Уникальность

Для одного Event и одного recipient обычно должна быть одна основная Notification конкретного канала/типа.

---

## 18.4. Acknowledgement

### Связи

`Event 1:N Acknowledgement`

`User/ProjectMember 1:N Acknowledgement`

`DocumentRevision 0..N Acknowledgement`

### Уникальность

`event + user + acknowledgement type`

не должен дублироваться.

---

## 18.5. Approval

### Связи

`Project 1:N Approval`

`Approval N:1 ProjectMember/User`

`Approval` связан с business target.

### Правило

Решение APPROVED/REJECTED/RETURNED immutable как факт.

Повторное согласование создаёт новый approval step/record.

---

## 18.6. Comment

### Связи

`Project 1:N Comment`

`User/ProjectMember 1:N Comment`

Comment связан с business target.

---

## 18.7. Attachment

### Связи

Attachment принадлежит:

- Project;
- uploader;
- business target.

### Правило

Удаление физического файла не должно разрушать исторически значимый документ.

Для critical documents требуется versioned/immutable strategy.

---

# 19. Audit

## 19.1. AuditEntry

### Связи

`Project 1:N AuditEntry`

`User 1:N AuditEntry`

AuditEntry относится к business target.

### Правила

- immutable;
- append-only;
- не удаляется обычным пользователем;
- хранит actor context;
- хранит before/after там, где это допустимо.

### Важно

Чувствительные поля нельзя бездумно копировать в Audit.

Нужна redaction policy.

---

# 20. Project isolation matrix

## 20.1. Direct `project_id` is mandatory

В physical PostgreSQL schema каждая project-scoped operational таблица имеет собственный `project_id`, даже если Project можно получить через parent relation.

Правило применяется также к child records: DocumentRevision/File/Impact, WorkProgressEntry/Requirement/Assignment, SupplyRequestItem, MaterialBatch, Inspection, QualityIssue, ExecutiveDocument, AcceptedWorkVolume, GeodeticTask/Survey, JournalEntry/Revision и другим operational rows.

Исключения: только явно global/master/reference сущности (например Permission, Organization, system role templates, глобальные справочники).

## 20.2. Same-project invariant

Если child хранит parent FK и `project_id`, БД должна защищать совпадение Project через composite FK, constraint, database function/trigger или другой проверяемый invariant. Frontend/Application-only проверка недостаточна.

## 20.3. Индексация

Каждая крупная project-scoped таблица имеет индекс, начинающийся с `project_id`. Дополнительные индексы создаются по реальным запросам, например `(project_id, status)`, `(project_id, created_at)`, `(project_id, work_id)`.

## 20.4. Organization dimension

Там, где запись принадлежит/видима определённой стороне объекта, дополнительно используется `project_organization_id` или иной явный organization scope. `project_id` изолирует объект; ProjectOrganization определяет сторону/ответственность внутри него.

---

# 21. Cross-project связи

По умолчанию запрещены.

Примеры запрещённых связей:

- Work объекта A → DocumentRevision объекта B;
- SupplyRequest объекта A → Work объекта B;
- ExecutivePackage объекта A → MaterialBatch объекта B;
- Task объекта A → assignee, не являющийся участником A;
- WorkAssignment объекта A → Employee без активного назначения на A.

Исключения должны быть явно описаны отдельным бизнес-правилом.

---

# 22. Уникальность и защита от дублей

Минимально предусмотреть логические ограничения.

## Membership

`Project + User` — одна активная membership.

## Document Revision

`TechnicalDocument + revision code` — unique.

## Acknowledgement

`Event + User + acknowledgement type` — unique.

## Invoice

защита от повторной регистрации одного счёта.

## Accepted Work Volume

один и тот же производственный объём нельзя закрыть коммерчески повторно.

## Active Responsibility

одна активная основная ResponsibilityAssignment для одной single-owner responsibility.

## Access Pass

не должно быть двух активных идентичных пропусков, если бизнес-процесс это запрещает.

---

# 23. Historical snapshots

Snapshot допустим только если необходимо сохранить историческое состояние.

Примеры:

- ФИО подписанта на момент подписания;
- должность;
- название организации;
- договорные реквизиты;
- название материала/обозначение;
- номер проектного документа.

Snapshot не становится master-data.

Изменение Employee/Counterparty/Material не должно переписывать уже закрытый юридически значимый документ.

---

# 24. Temporal data

Для сущностей со временем действия требуется различать:

- дата создания записи;
- дата бизнес-события;
- период действия;
- дата подтверждения;
- дата закрытия.

Особенно:

- Project membership;
- ResponsibilityAssignment;
- SafetyCertificate;
- WorkAdmission;
- WorkPermit;
- AccessPass;
- DocumentIssueForWork;
- Contract;
- EmployeeProjectAssignment.

---

# 25. Soft deletion / lifecycle

Не следует использовать один универсальный `is_deleted` как замену бизнес-статусам.

Примеры:

TechnicalDocument:

- active;
- superseded;
- annulled.

WorkPermit:

- active;
- suspended;
- expired;
- closed.

Project:

- active;
- archived.

Soft delete может существовать технически, но не заменяет business lifecycle.

---

# 26. Cross-domain references — решение v1.1

Свободная ссылка `entity_type + entity_id` не используется как основной способ связи operational сущностей, поскольку не обеспечивает полноценную PostgreSQL referential integrity.

## Operational links

`Task`, `Approval`, `Attachment`, `Comment` используют явные FK или explicit domain link tables. Добавление нового target type требует migration — это намеренно.

Примеры: `task_work`, `task_document_impact`, `task_quality_issue`, `approval_supply_request`, domain-specific attachment links.

## Historical links

`Event` и `AuditEntry` могут хранить `subject_type + subject_id` вместе с обязательным `project_id` и безопасным snapshot metadata, потому что являются append-only историей.

`Notification` ссылается на Event. `Acknowledgement` по умолчанию ссылается на Event; workflow-specific строгие связи добавляются явным FK/link table.

Запрещено вводить generic `entity_registry/business_objects` без нового ADR.

---

# 27. Что нельзя превращать в JSON-blob без причины

Не следует складывать основные бизнес-данные в универсальное поле `data JSON`.

Особенно:

- Work;
- WorkProgress;
- SupplyRequest;
- Inspection;
- QualityIssue;
- WorkPermit;
- Payment;
- KS;
- SafetyCertificate.

JSON допустим:

- для внешних payload;
- редких расширяемых metadata;
- snapshots;
- необязательных технических атрибутов.

Критические бизнес-поля должны иметь явную структуру.

---

# 28. Что можно вычислять, а не хранить как источник истины

## Progress percentage

Вычисляется из:

- planned quantity;
- confirmed progress quantity.

## Overdue

Вычисляется из:

- due date;
- current state.

## Material availability for Work

Вычисляется из:

- requirements;
- accepted batches;
- movements/reservations.

## Employee allowed for Work

Опирается на:

- SafetyCertificate;
- SafetyBriefing;
- WorkAdmission;
- WorkPermit.

## ID completeness

Вычисляется из:

- ExecutiveRequirement;
- ExecutiveDocument.

## Available commercial volume

Вычисляется из:

- confirmed WorkProgress;
- AcceptedWorkVolume already closed.

---

# 29. Первый vertical slice — логическая модель

Для первого рабочего сценария достаточно следующих связей:

```text
Organization
├── OrganizationMember ── User
└── ProjectOrganization ── Project
                            ├── ProjectArea
                            ├── ProjectMember
                            │   ├── User
                            │   └── Role
                            │       └── Permission
                            ├── TechnicalDocument
                            │   └── DocumentRevision
                            │       └── DocumentIssueForWork
                            │           └── DocumentImpact
                            │               └── Work
                            ├── Task
                            ├── Event
                            │   ├── Notification
                            │   └── Acknowledgement
                            └── AuditEntry
```

## Сценарий

1. ПТО создаёт DocumentRevision.
2. Ревизия проходит workflow.
3. Создаётся DocumentIssueForWork.
4. Определяются связанные Work.
5. Создаётся DocumentImpact.
6. Если требуется действие — создаётся Task.
7. Создаётся Event.
8. Ответственный получает Notification.
9. Пользователь подтверждает Acknowledgement.
10. Все критические переходы фиксируются AuditEntry.

Этот срез должен быть первым архитектурным тестом приложения.

---

# 30. Предварительная ER-карта

```text
Organization
├──< OrganizationMember >── User
└──< ProjectOrganization >── Project
                              ├──< ProjectArea
                              ├──< ProjectMember >── User
                              ├──< TechnicalDocument
                              │      └──< DocumentRevision
                              │             └──< DocumentIssueForWork
                              │                    └──< DocumentImpact >── Work
                              ├──< Work
                              │    ├──< WorkProgressEntry
                              │    ├──< WorkAssignment >── Employee
                              │    ├──< WorkRequirement
                              │    ├──< MaterialRequirement >── Material
                              │    ├──< Inspection
                              │    ├──< GeodeticTask
                              │    │      └──< GeodeticSurvey
                              │    ├──< ExecutivePackage
                              │    ├──< JournalEntry
                              │    └──< AcceptedWorkVolume
                              ├──< SupplyRequest
                              │    └──< SupplyRequestItem >── Material
                              ├──< Delivery
                              │    └──< MaterialBatch
                              │          └──< IncomingMaterialInspection
                              ├──< Contract >── Counterparty >── Organization
                              ├──< ElectronicJournal
                              ├──< ClosingPeriod
                              │    └──< AcceptedWorkVolume
                              ├──< WorkPermit
                              ├──< Task
                              ├──< Event
                              │    ├──< Notification
                              │    └──< Acknowledgement
                              └──< AuditEntry
```

---

# 31. Решения, которые должны быть приняты перед physical schema

Перед написанием SQL необходимо определить:

1. Supabase/PostgreSQL остаётся ли основной persistence-платформой.
2. Детализировать типы ProjectOrganization и cross-organization visibility для конкретных workflows.
3. Один User может иметь несколько Role в одном Project или только одну primary role.
4. ProjectArea:
   - adjacency list;
   - materialized path;
   - другая иерархическая модель.
5. Для каждого нового operational target определить явную FK/link table согласно разделу 26.
6. Нужен ли полноценный inventory/warehouse в MVP.
7. Как хранить версии файлов.
8. Как реализовать immutable audit.
9. Какие sensitive fields требуют encryption/masking.
10. Какие данные нужны offline.
11. Какой уровень данных должен быть доступен внешним участникам.
12. Нужно ли хранить organization snapshot в юридических документах.
13. Нужна ли юридически значимая ЭП.
14. Какие электронные журналы входят в MVP.

---

# 32. Что делать после утверждения logical model

Следующий документ:

`docs/architecture/ARCHITECTURE.md`

Он должен определить техническую платформу:

- frontend;
- backend boundary;
- server/client responsibilities;
- Supabase;
- Auth;
- RLS;
- Storage;
- domain/module structure;
- validation;
- data access;
- events/notifications;
- PWA;
- offline;
- testing;
- observability.

После этого:

`docs/architecture/database-physical.md`

с физической PostgreSQL/Supabase-схемой.

---

# 33. Definition of Done

Logical Data Model считается готовой для следующего этапа, если:

- ключевые cardinality определены;
- источники истины не дублируются;
- Project isolation определена;
- cross-project links запрещены по умолчанию;
- критические unique constraints понятны;
- historical snapshot отделён от master-data;
- вычисляемые данные отделены от первичных;
- vertical slice имеет минимальный набор сущностей;
- открытые архитектурные решения явно перечислены.
