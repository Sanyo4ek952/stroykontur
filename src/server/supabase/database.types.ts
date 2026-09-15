export type Json =
  | string
  | number
  | boolean
  | null
  | { [key: string]: Json | undefined }
  | Json[];

export type Database = {
  graphql_public: {
    Tables: {
      [_ in never]: never;
    };
    Views: {
      [_ in never]: never;
    };
    Functions: {
      graphql: {
        Args: {
          extensions?: Json;
          operationName?: string;
          query?: string;
          variables?: Json;
        };
        Returns: Json;
      };
    };
    Enums: {
      [_ in never]: never;
    };
    CompositeTypes: {
      [_ in never]: never;
    };
  };
  public: {
    Tables: {
      acknowledgement_document_impacts: {
        Row: {
          acknowledgement_id: string;
          created_at: string;
          document_impact_id: string;
          id: string;
          notification_id: string;
          project_id: string;
          project_member_id: string;
          task_id: string;
        };
        Insert: {
          acknowledgement_id: string;
          created_at?: string;
          document_impact_id: string;
          id?: string;
          notification_id: string;
          project_id: string;
          project_member_id: string;
          task_id: string;
        };
        Update: {
          acknowledgement_id?: string;
          created_at?: string;
          document_impact_id?: string;
          id?: string;
          notification_id?: string;
          project_id?: string;
          project_member_id?: string;
          task_id?: string;
        };
        Relationships: [
          {
            foreignKeyName: "acknowledgement_document_impacts_acknowledgement_fkey";
            columns: ["project_id", "project_member_id", "acknowledgement_id"];
            isOneToOne: false;
            referencedRelation: "acknowledgements";
            referencedColumns: ["project_id", "project_member_id", "id"];
          },
          {
            foreignKeyName: "acknowledgement_document_impacts_document_impact_fkey";
            columns: ["project_id", "document_impact_id"];
            isOneToOne: false;
            referencedRelation: "document_impacts";
            referencedColumns: ["project_id", "id"];
          },
          {
            foreignKeyName: "acknowledgement_document_impacts_notification_fkey";
            columns: ["project_id", "notification_id"];
            isOneToOne: true;
            referencedRelation: "notifications";
            referencedColumns: ["project_id", "id"];
          },
          {
            foreignKeyName: "acknowledgement_document_impacts_project_id_fkey";
            columns: ["project_id"];
            isOneToOne: false;
            referencedRelation: "projects";
            referencedColumns: ["id"];
          },
          {
            foreignKeyName: "acknowledgement_document_impacts_task_fkey";
            columns: ["project_id", "task_id"];
            isOneToOne: false;
            referencedRelation: "tasks";
            referencedColumns: ["project_id", "id"];
          },
        ];
      };
      acknowledgements: {
        Row: {
          acknowledged_at: string;
          acknowledgement_type: string;
          created_at: string;
          id: string;
          project_id: string;
          project_member_id: string;
        };
        Insert: {
          acknowledged_at?: string;
          acknowledgement_type: string;
          created_at?: string;
          id?: string;
          project_id: string;
          project_member_id: string;
        };
        Update: {
          acknowledged_at?: string;
          acknowledgement_type?: string;
          created_at?: string;
          id?: string;
          project_id?: string;
          project_member_id?: string;
        };
        Relationships: [
          {
            foreignKeyName: "acknowledgements_project_id_fkey";
            columns: ["project_id"];
            isOneToOne: false;
            referencedRelation: "projects";
            referencedColumns: ["id"];
          },
          {
            foreignKeyName: "acknowledgements_project_member_fkey";
            columns: ["project_id", "project_member_id"];
            isOneToOne: false;
            referencedRelation: "project_area_member_candidates";
            referencedColumns: ["project_id", "id"];
          },
          {
            foreignKeyName: "acknowledgements_project_member_fkey";
            columns: ["project_id", "project_member_id"];
            isOneToOne: false;
            referencedRelation: "project_members";
            referencedColumns: ["project_id", "id"];
          },
          {
            foreignKeyName: "acknowledgements_project_member_fkey";
            columns: ["project_id", "project_member_id"];
            isOneToOne: false;
            referencedRelation: "work_assignment_candidates";
            referencedColumns: ["project_id", "id"];
          },
        ];
      };
      audit_entries: {
        Row: {
          action_key: string;
          actor_project_member_id: string | null;
          actor_user_id: string | null;
          area_change_id: string | null;
          area_reason: string | null;
          assignment_change_id: string | null;
          assignment_reason: string | null;
          created_at: string;
          daily_report_command_id: string | null;
          daily_report_id: string | null;
          from_project_member_id: string | null;
          id: string;
          inspection_id: string | null;
          inspection_request_id: string | null;
          lifecycle_transition_id: string | null;
          occurred_at: string;
          progress_change_id: string | null;
          progress_decision_id: string | null;
          progress_decision_reason: string | null;
          project_area_id: string | null;
          project_id: string;
          project_member_area_id: string | null;
          quality_inspection_command_id: string | null;
          subject_id: string;
          subject_type: string;
          to_project_member_id: string | null;
          work_blocker_command_id: string | null;
          work_blocker_id: string | null;
          work_progress_entry_id: string | null;
        };
        Insert: {
          action_key: string;
          actor_project_member_id?: string | null;
          actor_user_id?: string | null;
          area_change_id?: string | null;
          area_reason?: string | null;
          assignment_change_id?: string | null;
          assignment_reason?: string | null;
          created_at?: string;
          daily_report_command_id?: string | null;
          daily_report_id?: string | null;
          from_project_member_id?: string | null;
          id?: string;
          inspection_id?: string | null;
          inspection_request_id?: string | null;
          lifecycle_transition_id?: string | null;
          occurred_at?: string;
          progress_change_id?: string | null;
          progress_decision_id?: string | null;
          progress_decision_reason?: string | null;
          project_area_id?: string | null;
          project_id: string;
          project_member_area_id?: string | null;
          quality_inspection_command_id?: string | null;
          subject_id: string;
          subject_type: string;
          to_project_member_id?: string | null;
          work_blocker_command_id?: string | null;
          work_blocker_id?: string | null;
          work_progress_entry_id?: string | null;
        };
        Update: {
          action_key?: string;
          actor_project_member_id?: string | null;
          actor_user_id?: string | null;
          area_change_id?: string | null;
          area_reason?: string | null;
          assignment_change_id?: string | null;
          assignment_reason?: string | null;
          created_at?: string;
          daily_report_command_id?: string | null;
          daily_report_id?: string | null;
          from_project_member_id?: string | null;
          id?: string;
          inspection_id?: string | null;
          inspection_request_id?: string | null;
          lifecycle_transition_id?: string | null;
          occurred_at?: string;
          progress_change_id?: string | null;
          progress_decision_id?: string | null;
          progress_decision_reason?: string | null;
          project_area_id?: string | null;
          project_id?: string;
          project_member_area_id?: string | null;
          quality_inspection_command_id?: string | null;
          subject_id?: string;
          subject_type?: string;
          to_project_member_id?: string | null;
          work_blocker_command_id?: string | null;
          work_blocker_id?: string | null;
          work_progress_entry_id?: string | null;
        };
        Relationships: [
          {
            foreignKeyName: "audit_entries_actor_project_member_fkey";
            columns: ["project_id", "actor_project_member_id"];
            isOneToOne: false;
            referencedRelation: "project_area_member_candidates";
            referencedColumns: ["project_id", "id"];
          },
          {
            foreignKeyName: "audit_entries_actor_project_member_fkey";
            columns: ["project_id", "actor_project_member_id"];
            isOneToOne: false;
            referencedRelation: "project_members";
            referencedColumns: ["project_id", "id"];
          },
          {
            foreignKeyName: "audit_entries_actor_project_member_fkey";
            columns: ["project_id", "actor_project_member_id"];
            isOneToOne: false;
            referencedRelation: "work_assignment_candidates";
            referencedColumns: ["project_id", "id"];
          },
          {
            foreignKeyName: "audit_entries_project_id_area_change_id_fkey";
            columns: ["project_id", "area_change_id"];
            isOneToOne: false;
            referencedRelation: "project_area_changes";
            referencedColumns: ["project_id", "command_id"];
          },
          {
            foreignKeyName: "audit_entries_project_id_assignment_change_id_fkey";
            columns: ["project_id", "assignment_change_id"];
            isOneToOne: false;
            referencedRelation: "work_assignment_changes";
            referencedColumns: ["project_id", "command_id"];
          },
          {
            foreignKeyName: "audit_entries_project_id_daily_report_command_id_fkey";
            columns: ["project_id", "daily_report_command_id"];
            isOneToOne: false;
            referencedRelation: "daily_report_commands";
            referencedColumns: ["project_id", "command_id"];
          },
          {
            foreignKeyName: "audit_entries_project_id_daily_report_id_fkey";
            columns: ["project_id", "daily_report_id"];
            isOneToOne: false;
            referencedRelation: "daily_reports";
            referencedColumns: ["project_id", "id"];
          },
          {
            foreignKeyName: "audit_entries_project_id_fkey";
            columns: ["project_id"];
            isOneToOne: false;
            referencedRelation: "projects";
            referencedColumns: ["id"];
          },
          {
            foreignKeyName: "audit_entries_project_id_from_project_member_id_fkey";
            columns: ["project_id", "from_project_member_id"];
            isOneToOne: false;
            referencedRelation: "project_area_member_candidates";
            referencedColumns: ["project_id", "id"];
          },
          {
            foreignKeyName: "audit_entries_project_id_from_project_member_id_fkey";
            columns: ["project_id", "from_project_member_id"];
            isOneToOne: false;
            referencedRelation: "project_members";
            referencedColumns: ["project_id", "id"];
          },
          {
            foreignKeyName: "audit_entries_project_id_from_project_member_id_fkey";
            columns: ["project_id", "from_project_member_id"];
            isOneToOne: false;
            referencedRelation: "work_assignment_candidates";
            referencedColumns: ["project_id", "id"];
          },
          {
            foreignKeyName: "audit_entries_project_id_inspection_id_fkey";
            columns: ["project_id", "inspection_id"];
            isOneToOne: false;
            referencedRelation: "inspections";
            referencedColumns: ["project_id", "id"];
          },
          {
            foreignKeyName: "audit_entries_project_id_inspection_request_id_fkey";
            columns: ["project_id", "inspection_request_id"];
            isOneToOne: false;
            referencedRelation: "inspection_requests";
            referencedColumns: ["project_id", "id"];
          },
          {
            foreignKeyName: "audit_entries_project_id_progress_change_id_fkey";
            columns: ["project_id", "progress_change_id"];
            isOneToOne: false;
            referencedRelation: "work_progress_changes";
            referencedColumns: ["project_id", "command_id"];
          },
          {
            foreignKeyName: "audit_entries_project_id_progress_decision_id_fkey";
            columns: ["project_id", "progress_decision_id"];
            isOneToOne: false;
            referencedRelation: "work_progress_decisions";
            referencedColumns: ["project_id", "command_id"];
          },
          {
            foreignKeyName: "audit_entries_project_id_project_member_area_id_fkey";
            columns: ["project_id", "project_member_area_id"];
            isOneToOne: false;
            referencedRelation: "project_member_areas";
            referencedColumns: ["project_id", "id"];
          },
          {
            foreignKeyName: "audit_entries_project_id_quality_inspection_command_id_fkey";
            columns: ["project_id", "quality_inspection_command_id"];
            isOneToOne: false;
            referencedRelation: "quality_inspection_commands";
            referencedColumns: ["project_id", "command_id"];
          },
          {
            foreignKeyName: "audit_entries_project_id_to_project_member_id_fkey";
            columns: ["project_id", "to_project_member_id"];
            isOneToOne: false;
            referencedRelation: "project_area_member_candidates";
            referencedColumns: ["project_id", "id"];
          },
          {
            foreignKeyName: "audit_entries_project_id_to_project_member_id_fkey";
            columns: ["project_id", "to_project_member_id"];
            isOneToOne: false;
            referencedRelation: "project_members";
            referencedColumns: ["project_id", "id"];
          },
          {
            foreignKeyName: "audit_entries_project_id_to_project_member_id_fkey";
            columns: ["project_id", "to_project_member_id"];
            isOneToOne: false;
            referencedRelation: "work_assignment_candidates";
            referencedColumns: ["project_id", "id"];
          },
          {
            foreignKeyName: "audit_entries_project_id_work_blocker_command_id_fkey";
            columns: ["project_id", "work_blocker_command_id"];
            isOneToOne: false;
            referencedRelation: "work_blocker_commands";
            referencedColumns: ["project_id", "command_id"];
          },
          {
            foreignKeyName: "audit_entries_project_id_work_blocker_id_fkey";
            columns: ["project_id", "work_blocker_id"];
            isOneToOne: false;
            referencedRelation: "work_blockers";
            referencedColumns: ["project_id", "id"];
          },
          {
            foreignKeyName: "audit_entries_project_id_work_progress_entry_id_fkey";
            columns: ["project_id", "work_progress_entry_id"];
            isOneToOne: false;
            referencedRelation: "work_progress_entries";
            referencedColumns: ["project_id", "id"];
          },
        ];
      };
      daily_report_commands: {
        Row: {
          actor_project_member_id: string;
          actor_user_id: string;
          command_id: string;
          daily_report_id: string;
          occurred_at: string;
          operation: string;
          payload: Json;
          project_area_id: string;
          project_id: string;
          transaction_id: unknown;
        };
        Insert: {
          actor_project_member_id: string;
          actor_user_id: string;
          command_id: string;
          daily_report_id: string;
          occurred_at?: string;
          operation: string;
          payload: Json;
          project_area_id: string;
          project_id: string;
          transaction_id?: unknown;
        };
        Update: {
          actor_project_member_id?: string;
          actor_user_id?: string;
          command_id?: string;
          daily_report_id?: string;
          occurred_at?: string;
          operation?: string;
          payload?: Json;
          project_area_id?: string;
          project_id?: string;
          transaction_id?: unknown;
        };
        Relationships: [
          {
            foreignKeyName: "daily_report_commands_project_id_actor_project_member_id_fkey";
            columns: ["project_id", "actor_project_member_id"];
            isOneToOne: false;
            referencedRelation: "project_area_member_candidates";
            referencedColumns: ["project_id", "id"];
          },
          {
            foreignKeyName: "daily_report_commands_project_id_actor_project_member_id_fkey";
            columns: ["project_id", "actor_project_member_id"];
            isOneToOne: false;
            referencedRelation: "project_members";
            referencedColumns: ["project_id", "id"];
          },
          {
            foreignKeyName: "daily_report_commands_project_id_actor_project_member_id_fkey";
            columns: ["project_id", "actor_project_member_id"];
            isOneToOne: false;
            referencedRelation: "work_assignment_candidates";
            referencedColumns: ["project_id", "id"];
          },
          {
            foreignKeyName: "daily_report_commands_project_id_daily_report_id_fkey";
            columns: ["project_id", "daily_report_id"];
            isOneToOne: false;
            referencedRelation: "daily_reports";
            referencedColumns: ["project_id", "id"];
          },
          {
            foreignKeyName: "daily_report_commands_project_id_fkey";
            columns: ["project_id"];
            isOneToOne: false;
            referencedRelation: "projects";
            referencedColumns: ["id"];
          },
          {
            foreignKeyName: "daily_report_commands_project_id_project_area_id_fkey";
            columns: ["project_id", "project_area_id"];
            isOneToOne: false;
            referencedRelation: "daily_report_area_capabilities";
            referencedColumns: ["project_id", "id"];
          },
          {
            foreignKeyName: "daily_report_commands_project_id_project_area_id_fkey";
            columns: ["project_id", "project_area_id"];
            isOneToOne: false;
            referencedRelation: "project_areas";
            referencedColumns: ["project_id", "id"];
          },
        ];
      };
      daily_reports: {
        Row: {
          confirmed_at: string | null;
          confirmed_by_project_member_id: string | null;
          created_at: string;
          id: string;
          prepared_by_project_member_id: string;
          problems: string | null;
          project_area_id: string;
          project_id: string;
          report_date: string;
          return_reason: string | null;
          returned_at: string | null;
          returned_by_project_member_id: string | null;
          status: string;
          submitted_at: string | null;
          submitted_by_project_member_id: string | null;
          summary: string | null;
          updated_at: string;
          workers_count: number;
        };
        Insert: {
          confirmed_at?: string | null;
          confirmed_by_project_member_id?: string | null;
          created_at?: string;
          id?: string;
          prepared_by_project_member_id: string;
          problems?: string | null;
          project_area_id: string;
          project_id: string;
          report_date: string;
          return_reason?: string | null;
          returned_at?: string | null;
          returned_by_project_member_id?: string | null;
          status?: string;
          submitted_at?: string | null;
          submitted_by_project_member_id?: string | null;
          summary?: string | null;
          updated_at?: string;
          workers_count: number;
        };
        Update: {
          confirmed_at?: string | null;
          confirmed_by_project_member_id?: string | null;
          created_at?: string;
          id?: string;
          prepared_by_project_member_id?: string;
          problems?: string | null;
          project_area_id?: string;
          project_id?: string;
          report_date?: string;
          return_reason?: string | null;
          returned_at?: string | null;
          returned_by_project_member_id?: string | null;
          status?: string;
          submitted_at?: string | null;
          submitted_by_project_member_id?: string | null;
          summary?: string | null;
          updated_at?: string;
          workers_count?: number;
        };
        Relationships: [
          {
            foreignKeyName: "daily_reports_project_id_confirmed_by_project_member_id_fkey";
            columns: ["project_id", "confirmed_by_project_member_id"];
            isOneToOne: false;
            referencedRelation: "project_area_member_candidates";
            referencedColumns: ["project_id", "id"];
          },
          {
            foreignKeyName: "daily_reports_project_id_confirmed_by_project_member_id_fkey";
            columns: ["project_id", "confirmed_by_project_member_id"];
            isOneToOne: false;
            referencedRelation: "project_members";
            referencedColumns: ["project_id", "id"];
          },
          {
            foreignKeyName: "daily_reports_project_id_confirmed_by_project_member_id_fkey";
            columns: ["project_id", "confirmed_by_project_member_id"];
            isOneToOne: false;
            referencedRelation: "work_assignment_candidates";
            referencedColumns: ["project_id", "id"];
          },
          {
            foreignKeyName: "daily_reports_project_id_fkey";
            columns: ["project_id"];
            isOneToOne: false;
            referencedRelation: "projects";
            referencedColumns: ["id"];
          },
          {
            foreignKeyName: "daily_reports_project_id_prepared_by_project_member_id_fkey";
            columns: ["project_id", "prepared_by_project_member_id"];
            isOneToOne: false;
            referencedRelation: "project_area_member_candidates";
            referencedColumns: ["project_id", "id"];
          },
          {
            foreignKeyName: "daily_reports_project_id_prepared_by_project_member_id_fkey";
            columns: ["project_id", "prepared_by_project_member_id"];
            isOneToOne: false;
            referencedRelation: "project_members";
            referencedColumns: ["project_id", "id"];
          },
          {
            foreignKeyName: "daily_reports_project_id_prepared_by_project_member_id_fkey";
            columns: ["project_id", "prepared_by_project_member_id"];
            isOneToOne: false;
            referencedRelation: "work_assignment_candidates";
            referencedColumns: ["project_id", "id"];
          },
          {
            foreignKeyName: "daily_reports_project_id_project_area_id_fkey";
            columns: ["project_id", "project_area_id"];
            isOneToOne: false;
            referencedRelation: "daily_report_area_capabilities";
            referencedColumns: ["project_id", "id"];
          },
          {
            foreignKeyName: "daily_reports_project_id_project_area_id_fkey";
            columns: ["project_id", "project_area_id"];
            isOneToOne: false;
            referencedRelation: "project_areas";
            referencedColumns: ["project_id", "id"];
          },
          {
            foreignKeyName: "daily_reports_project_id_returned_by_project_member_id_fkey";
            columns: ["project_id", "returned_by_project_member_id"];
            isOneToOne: false;
            referencedRelation: "project_area_member_candidates";
            referencedColumns: ["project_id", "id"];
          },
          {
            foreignKeyName: "daily_reports_project_id_returned_by_project_member_id_fkey";
            columns: ["project_id", "returned_by_project_member_id"];
            isOneToOne: false;
            referencedRelation: "project_members";
            referencedColumns: ["project_id", "id"];
          },
          {
            foreignKeyName: "daily_reports_project_id_returned_by_project_member_id_fkey";
            columns: ["project_id", "returned_by_project_member_id"];
            isOneToOne: false;
            referencedRelation: "work_assignment_candidates";
            referencedColumns: ["project_id", "id"];
          },
          {
            foreignKeyName: "daily_reports_project_id_submitted_by_project_member_id_fkey";
            columns: ["project_id", "submitted_by_project_member_id"];
            isOneToOne: false;
            referencedRelation: "project_area_member_candidates";
            referencedColumns: ["project_id", "id"];
          },
          {
            foreignKeyName: "daily_reports_project_id_submitted_by_project_member_id_fkey";
            columns: ["project_id", "submitted_by_project_member_id"];
            isOneToOne: false;
            referencedRelation: "project_members";
            referencedColumns: ["project_id", "id"];
          },
          {
            foreignKeyName: "daily_reports_project_id_submitted_by_project_member_id_fkey";
            columns: ["project_id", "submitted_by_project_member_id"];
            isOneToOne: false;
            referencedRelation: "work_assignment_candidates";
            referencedColumns: ["project_id", "id"];
          },
        ];
      };
      document_impacts: {
        Row: {
          created_at: string;
          detected_at: string;
          document_issue_for_work_id: string;
          document_work_link_id: string;
          id: string;
          project_id: string;
          status: string;
          technical_document_id: string;
          work_id: string;
        };
        Insert: {
          created_at?: string;
          detected_at?: string;
          document_issue_for_work_id: string;
          document_work_link_id: string;
          id?: string;
          project_id: string;
          status?: string;
          technical_document_id: string;
          work_id: string;
        };
        Update: {
          created_at?: string;
          detected_at?: string;
          document_issue_for_work_id?: string;
          document_work_link_id?: string;
          id?: string;
          project_id?: string;
          status?: string;
          technical_document_id?: string;
          work_id?: string;
        };
        Relationships: [
          {
            foreignKeyName: "document_impacts_document_issue_for_work_fkey";
            columns: [
              "project_id",
              "technical_document_id",
              "document_issue_for_work_id",
            ];
            isOneToOne: false;
            referencedRelation: "document_issues_for_work";
            referencedColumns: ["project_id", "technical_document_id", "id"];
          },
          {
            foreignKeyName: "document_impacts_document_work_link_fkey";
            columns: [
              "project_id",
              "technical_document_id",
              "work_id",
              "document_work_link_id",
            ];
            isOneToOne: false;
            referencedRelation: "document_work_links";
            referencedColumns: [
              "project_id",
              "technical_document_id",
              "work_id",
              "id",
            ];
          },
          {
            foreignKeyName: "document_impacts_project_id_fkey";
            columns: ["project_id"];
            isOneToOne: false;
            referencedRelation: "projects";
            referencedColumns: ["id"];
          },
        ];
      };
      document_issues_for_work: {
        Row: {
          created_at: string;
          document_revision_id: string;
          id: string;
          issued_at: string;
          issued_by: string;
          project_id: string;
          technical_document_id: string;
          withdrawal_reason: string | null;
          withdrawn_at: string | null;
          withdrawn_by: string | null;
        };
        Insert: {
          created_at?: string;
          document_revision_id: string;
          id?: string;
          issued_at?: string;
          issued_by: string;
          project_id: string;
          technical_document_id: string;
          withdrawal_reason?: string | null;
          withdrawn_at?: string | null;
          withdrawn_by?: string | null;
        };
        Update: {
          created_at?: string;
          document_revision_id?: string;
          id?: string;
          issued_at?: string;
          issued_by?: string;
          project_id?: string;
          technical_document_id?: string;
          withdrawal_reason?: string | null;
          withdrawn_at?: string | null;
          withdrawn_by?: string | null;
        };
        Relationships: [
          {
            foreignKeyName: "document_issues_for_work_document_revision_fkey";
            columns: [
              "project_id",
              "technical_document_id",
              "document_revision_id",
            ];
            isOneToOne: false;
            referencedRelation: "document_revisions";
            referencedColumns: ["project_id", "technical_document_id", "id"];
          },
          {
            foreignKeyName: "document_issues_for_work_project_id_fkey";
            columns: ["project_id"];
            isOneToOne: false;
            referencedRelation: "projects";
            referencedColumns: ["id"];
          },
          {
            foreignKeyName: "document_issues_for_work_technical_document_fkey";
            columns: ["project_id", "technical_document_id"];
            isOneToOne: false;
            referencedRelation: "technical_documents";
            referencedColumns: ["project_id", "id"];
          },
        ];
      };
      document_revisions: {
        Row: {
          created_at: string;
          created_by: string;
          id: string;
          project_id: string;
          revision_code: string;
          status: string;
          technical_document_id: string;
          updated_at: string;
        };
        Insert: {
          created_at?: string;
          created_by: string;
          id?: string;
          project_id: string;
          revision_code: string;
          status?: string;
          technical_document_id: string;
          updated_at?: string;
        };
        Update: {
          created_at?: string;
          created_by?: string;
          id?: string;
          project_id?: string;
          revision_code?: string;
          status?: string;
          technical_document_id?: string;
          updated_at?: string;
        };
        Relationships: [
          {
            foreignKeyName: "document_revisions_project_id_fkey";
            columns: ["project_id"];
            isOneToOne: false;
            referencedRelation: "projects";
            referencedColumns: ["id"];
          },
          {
            foreignKeyName: "document_revisions_technical_document_fkey";
            columns: ["project_id", "technical_document_id"];
            isOneToOne: false;
            referencedRelation: "technical_documents";
            referencedColumns: ["project_id", "id"];
          },
        ];
      };
      document_work_links: {
        Row: {
          created_at: string;
          created_by: string;
          id: string;
          project_id: string;
          removal_reason: string | null;
          removed_at: string | null;
          removed_by: string | null;
          technical_document_id: string;
          work_id: string;
        };
        Insert: {
          created_at?: string;
          created_by: string;
          id?: string;
          project_id: string;
          removal_reason?: string | null;
          removed_at?: string | null;
          removed_by?: string | null;
          technical_document_id: string;
          work_id: string;
        };
        Update: {
          created_at?: string;
          created_by?: string;
          id?: string;
          project_id?: string;
          removal_reason?: string | null;
          removed_at?: string | null;
          removed_by?: string | null;
          technical_document_id?: string;
          work_id?: string;
        };
        Relationships: [
          {
            foreignKeyName: "document_work_links_project_id_fkey";
            columns: ["project_id"];
            isOneToOne: false;
            referencedRelation: "projects";
            referencedColumns: ["id"];
          },
          {
            foreignKeyName: "document_work_links_technical_document_fkey";
            columns: ["project_id", "technical_document_id"];
            isOneToOne: false;
            referencedRelation: "technical_documents";
            referencedColumns: ["project_id", "id"];
          },
          {
            foreignKeyName: "document_work_links_work_fkey";
            columns: ["project_id", "work_id"];
            isOneToOne: false;
            referencedRelation: "works";
            referencedColumns: ["project_id", "id"];
          },
        ];
      };
      events: {
        Row: {
          actor_user_id: string | null;
          area_change_id: string | null;
          area_reason: string | null;
          assignment_change_id: string | null;
          created_at: string;
          daily_report_command_id: string | null;
          daily_report_id: string | null;
          event_type: string;
          from_project_member_id: string | null;
          from_status: string | null;
          id: string;
          inspection_id: string | null;
          inspection_request_id: string | null;
          lifecycle_transition_id: string | null;
          occurred_at: string;
          progress_change_id: string | null;
          progress_decision_id: string | null;
          progress_decision_reason: string | null;
          project_area_id: string | null;
          project_id: string;
          project_member_area_id: string | null;
          quality_inspection_command_id: string | null;
          subject_id: string;
          subject_type: string;
          to_project_member_id: string | null;
          to_status: string | null;
          work_blocker_command_id: string | null;
          work_blocker_id: string | null;
          work_progress_entry_id: string | null;
        };
        Insert: {
          actor_user_id?: string | null;
          area_change_id?: string | null;
          area_reason?: string | null;
          assignment_change_id?: string | null;
          created_at?: string;
          daily_report_command_id?: string | null;
          daily_report_id?: string | null;
          event_type: string;
          from_project_member_id?: string | null;
          from_status?: string | null;
          id?: string;
          inspection_id?: string | null;
          inspection_request_id?: string | null;
          lifecycle_transition_id?: string | null;
          occurred_at?: string;
          progress_change_id?: string | null;
          progress_decision_id?: string | null;
          progress_decision_reason?: string | null;
          project_area_id?: string | null;
          project_id: string;
          project_member_area_id?: string | null;
          quality_inspection_command_id?: string | null;
          subject_id: string;
          subject_type: string;
          to_project_member_id?: string | null;
          to_status?: string | null;
          work_blocker_command_id?: string | null;
          work_blocker_id?: string | null;
          work_progress_entry_id?: string | null;
        };
        Update: {
          actor_user_id?: string | null;
          area_change_id?: string | null;
          area_reason?: string | null;
          assignment_change_id?: string | null;
          created_at?: string;
          daily_report_command_id?: string | null;
          daily_report_id?: string | null;
          event_type?: string;
          from_project_member_id?: string | null;
          from_status?: string | null;
          id?: string;
          inspection_id?: string | null;
          inspection_request_id?: string | null;
          lifecycle_transition_id?: string | null;
          occurred_at?: string;
          progress_change_id?: string | null;
          progress_decision_id?: string | null;
          progress_decision_reason?: string | null;
          project_area_id?: string | null;
          project_id?: string;
          project_member_area_id?: string | null;
          quality_inspection_command_id?: string | null;
          subject_id?: string;
          subject_type?: string;
          to_project_member_id?: string | null;
          to_status?: string | null;
          work_blocker_command_id?: string | null;
          work_blocker_id?: string | null;
          work_progress_entry_id?: string | null;
        };
        Relationships: [
          {
            foreignKeyName: "events_project_id_area_change_id_fkey";
            columns: ["project_id", "area_change_id"];
            isOneToOne: false;
            referencedRelation: "project_area_changes";
            referencedColumns: ["project_id", "command_id"];
          },
          {
            foreignKeyName: "events_project_id_assignment_change_id_fkey";
            columns: ["project_id", "assignment_change_id"];
            isOneToOne: false;
            referencedRelation: "work_assignment_changes";
            referencedColumns: ["project_id", "command_id"];
          },
          {
            foreignKeyName: "events_project_id_daily_report_command_id_fkey";
            columns: ["project_id", "daily_report_command_id"];
            isOneToOne: false;
            referencedRelation: "daily_report_commands";
            referencedColumns: ["project_id", "command_id"];
          },
          {
            foreignKeyName: "events_project_id_daily_report_id_fkey";
            columns: ["project_id", "daily_report_id"];
            isOneToOne: false;
            referencedRelation: "daily_reports";
            referencedColumns: ["project_id", "id"];
          },
          {
            foreignKeyName: "events_project_id_fkey";
            columns: ["project_id"];
            isOneToOne: false;
            referencedRelation: "projects";
            referencedColumns: ["id"];
          },
          {
            foreignKeyName: "events_project_id_from_project_member_id_fkey";
            columns: ["project_id", "from_project_member_id"];
            isOneToOne: false;
            referencedRelation: "project_area_member_candidates";
            referencedColumns: ["project_id", "id"];
          },
          {
            foreignKeyName: "events_project_id_from_project_member_id_fkey";
            columns: ["project_id", "from_project_member_id"];
            isOneToOne: false;
            referencedRelation: "project_members";
            referencedColumns: ["project_id", "id"];
          },
          {
            foreignKeyName: "events_project_id_from_project_member_id_fkey";
            columns: ["project_id", "from_project_member_id"];
            isOneToOne: false;
            referencedRelation: "work_assignment_candidates";
            referencedColumns: ["project_id", "id"];
          },
          {
            foreignKeyName: "events_project_id_inspection_id_fkey";
            columns: ["project_id", "inspection_id"];
            isOneToOne: false;
            referencedRelation: "inspections";
            referencedColumns: ["project_id", "id"];
          },
          {
            foreignKeyName: "events_project_id_inspection_request_id_fkey";
            columns: ["project_id", "inspection_request_id"];
            isOneToOne: false;
            referencedRelation: "inspection_requests";
            referencedColumns: ["project_id", "id"];
          },
          {
            foreignKeyName: "events_project_id_progress_change_id_fkey";
            columns: ["project_id", "progress_change_id"];
            isOneToOne: false;
            referencedRelation: "work_progress_changes";
            referencedColumns: ["project_id", "command_id"];
          },
          {
            foreignKeyName: "events_project_id_progress_decision_id_fkey";
            columns: ["project_id", "progress_decision_id"];
            isOneToOne: false;
            referencedRelation: "work_progress_decisions";
            referencedColumns: ["project_id", "command_id"];
          },
          {
            foreignKeyName: "events_project_id_project_member_area_id_fkey";
            columns: ["project_id", "project_member_area_id"];
            isOneToOne: false;
            referencedRelation: "project_member_areas";
            referencedColumns: ["project_id", "id"];
          },
          {
            foreignKeyName: "events_project_id_quality_inspection_command_id_fkey";
            columns: ["project_id", "quality_inspection_command_id"];
            isOneToOne: false;
            referencedRelation: "quality_inspection_commands";
            referencedColumns: ["project_id", "command_id"];
          },
          {
            foreignKeyName: "events_project_id_to_project_member_id_fkey";
            columns: ["project_id", "to_project_member_id"];
            isOneToOne: false;
            referencedRelation: "project_area_member_candidates";
            referencedColumns: ["project_id", "id"];
          },
          {
            foreignKeyName: "events_project_id_to_project_member_id_fkey";
            columns: ["project_id", "to_project_member_id"];
            isOneToOne: false;
            referencedRelation: "project_members";
            referencedColumns: ["project_id", "id"];
          },
          {
            foreignKeyName: "events_project_id_to_project_member_id_fkey";
            columns: ["project_id", "to_project_member_id"];
            isOneToOne: false;
            referencedRelation: "work_assignment_candidates";
            referencedColumns: ["project_id", "id"];
          },
          {
            foreignKeyName: "events_project_id_work_blocker_command_id_fkey";
            columns: ["project_id", "work_blocker_command_id"];
            isOneToOne: false;
            referencedRelation: "work_blocker_commands";
            referencedColumns: ["project_id", "command_id"];
          },
          {
            foreignKeyName: "events_project_id_work_blocker_id_fkey";
            columns: ["project_id", "work_blocker_id"];
            isOneToOne: false;
            referencedRelation: "work_blockers";
            referencedColumns: ["project_id", "id"];
          },
          {
            foreignKeyName: "events_project_id_work_progress_entry_id_fkey";
            columns: ["project_id", "work_progress_entry_id"];
            isOneToOne: false;
            referencedRelation: "work_progress_entries";
            referencedColumns: ["project_id", "id"];
          },
        ];
      };
      inspection_requests: {
        Row: {
          created_at: string;
          id: string;
          project_area_id: string;
          project_id: string;
          requested_at: string;
          requested_by_project_member_id: string;
          scheduled_at: string | null;
          scheduled_by_project_member_id: string | null;
          status: string;
          updated_at: string;
          work_id: string;
        };
        Insert: {
          created_at?: string;
          id?: string;
          project_area_id: string;
          project_id: string;
          requested_at?: string;
          requested_by_project_member_id: string;
          scheduled_at?: string | null;
          scheduled_by_project_member_id?: string | null;
          status?: string;
          updated_at?: string;
          work_id: string;
        };
        Update: {
          created_at?: string;
          id?: string;
          project_area_id?: string;
          project_id?: string;
          requested_at?: string;
          requested_by_project_member_id?: string;
          scheduled_at?: string | null;
          scheduled_by_project_member_id?: string | null;
          status?: string;
          updated_at?: string;
          work_id?: string;
        };
        Relationships: [
          {
            foreignKeyName: "inspection_requests_area_fkey";
            columns: ["project_id", "project_area_id"];
            isOneToOne: false;
            referencedRelation: "daily_report_area_capabilities";
            referencedColumns: ["project_id", "id"];
          },
          {
            foreignKeyName: "inspection_requests_area_fkey";
            columns: ["project_id", "project_area_id"];
            isOneToOne: false;
            referencedRelation: "project_areas";
            referencedColumns: ["project_id", "id"];
          },
          {
            foreignKeyName: "inspection_requests_project_fkey";
            columns: ["project_id"];
            isOneToOne: false;
            referencedRelation: "projects";
            referencedColumns: ["id"];
          },
          {
            foreignKeyName: "inspection_requests_requested_by_fkey";
            columns: ["project_id", "requested_by_project_member_id"];
            isOneToOne: false;
            referencedRelation: "project_area_member_candidates";
            referencedColumns: ["project_id", "id"];
          },
          {
            foreignKeyName: "inspection_requests_requested_by_fkey";
            columns: ["project_id", "requested_by_project_member_id"];
            isOneToOne: false;
            referencedRelation: "project_members";
            referencedColumns: ["project_id", "id"];
          },
          {
            foreignKeyName: "inspection_requests_requested_by_fkey";
            columns: ["project_id", "requested_by_project_member_id"];
            isOneToOne: false;
            referencedRelation: "work_assignment_candidates";
            referencedColumns: ["project_id", "id"];
          },
          {
            foreignKeyName: "inspection_requests_scheduled_by_fkey";
            columns: ["project_id", "scheduled_by_project_member_id"];
            isOneToOne: false;
            referencedRelation: "project_area_member_candidates";
            referencedColumns: ["project_id", "id"];
          },
          {
            foreignKeyName: "inspection_requests_scheduled_by_fkey";
            columns: ["project_id", "scheduled_by_project_member_id"];
            isOneToOne: false;
            referencedRelation: "project_members";
            referencedColumns: ["project_id", "id"];
          },
          {
            foreignKeyName: "inspection_requests_scheduled_by_fkey";
            columns: ["project_id", "scheduled_by_project_member_id"];
            isOneToOne: false;
            referencedRelation: "work_assignment_candidates";
            referencedColumns: ["project_id", "id"];
          },
          {
            foreignKeyName: "inspection_requests_work_fkey";
            columns: ["project_id", "work_id"];
            isOneToOne: false;
            referencedRelation: "works";
            referencedColumns: ["project_id", "id"];
          },
        ];
      };
      inspections: {
        Row: {
          accepted_at: string | null;
          created_at: string;
          id: string;
          inspection_request_id: string;
          inspector_project_member_id: string;
          project_area_id: string;
          project_id: string;
          result_note: string | null;
          scheduled_at: string;
          started_at: string | null;
          status: string;
          updated_at: string;
          work_id: string;
        };
        Insert: {
          accepted_at?: string | null;
          created_at?: string;
          id?: string;
          inspection_request_id: string;
          inspector_project_member_id: string;
          project_area_id: string;
          project_id: string;
          result_note?: string | null;
          scheduled_at?: string;
          started_at?: string | null;
          status?: string;
          updated_at?: string;
          work_id: string;
        };
        Update: {
          accepted_at?: string | null;
          created_at?: string;
          id?: string;
          inspection_request_id?: string;
          inspector_project_member_id?: string;
          project_area_id?: string;
          project_id?: string;
          result_note?: string | null;
          scheduled_at?: string;
          started_at?: string | null;
          status?: string;
          updated_at?: string;
          work_id?: string;
        };
        Relationships: [
          {
            foreignKeyName: "inspections_area_fkey";
            columns: ["project_id", "project_area_id"];
            isOneToOne: false;
            referencedRelation: "daily_report_area_capabilities";
            referencedColumns: ["project_id", "id"];
          },
          {
            foreignKeyName: "inspections_area_fkey";
            columns: ["project_id", "project_area_id"];
            isOneToOne: false;
            referencedRelation: "project_areas";
            referencedColumns: ["project_id", "id"];
          },
          {
            foreignKeyName: "inspections_inspector_fkey";
            columns: ["project_id", "inspector_project_member_id"];
            isOneToOne: false;
            referencedRelation: "project_area_member_candidates";
            referencedColumns: ["project_id", "id"];
          },
          {
            foreignKeyName: "inspections_inspector_fkey";
            columns: ["project_id", "inspector_project_member_id"];
            isOneToOne: false;
            referencedRelation: "project_members";
            referencedColumns: ["project_id", "id"];
          },
          {
            foreignKeyName: "inspections_inspector_fkey";
            columns: ["project_id", "inspector_project_member_id"];
            isOneToOne: false;
            referencedRelation: "work_assignment_candidates";
            referencedColumns: ["project_id", "id"];
          },
          {
            foreignKeyName: "inspections_project_fkey";
            columns: ["project_id"];
            isOneToOne: false;
            referencedRelation: "projects";
            referencedColumns: ["id"];
          },
          {
            foreignKeyName: "inspections_request_context_fkey";
            columns: [
              "project_id",
              "inspection_request_id",
              "work_id",
              "project_area_id",
            ];
            isOneToOne: false;
            referencedRelation: "inspection_requests";
            referencedColumns: [
              "project_id",
              "id",
              "work_id",
              "project_area_id",
            ];
          },
          {
            foreignKeyName: "inspections_work_fkey";
            columns: ["project_id", "work_id"];
            isOneToOne: false;
            referencedRelation: "works";
            referencedColumns: ["project_id", "id"];
          },
        ];
      };
      notifications: {
        Row: {
          created_at: string;
          event_id: string;
          id: string;
          project_id: string;
          read_at: string | null;
          recipient_project_member_id: string;
        };
        Insert: {
          created_at?: string;
          event_id: string;
          id?: string;
          project_id: string;
          read_at?: string | null;
          recipient_project_member_id: string;
        };
        Update: {
          created_at?: string;
          event_id?: string;
          id?: string;
          project_id?: string;
          read_at?: string | null;
          recipient_project_member_id?: string;
        };
        Relationships: [
          {
            foreignKeyName: "notifications_event_fkey";
            columns: ["project_id", "event_id"];
            isOneToOne: false;
            referencedRelation: "events";
            referencedColumns: ["project_id", "id"];
          },
          {
            foreignKeyName: "notifications_project_id_fkey";
            columns: ["project_id"];
            isOneToOne: false;
            referencedRelation: "projects";
            referencedColumns: ["id"];
          },
          {
            foreignKeyName: "notifications_recipient_project_member_fkey";
            columns: ["project_id", "recipient_project_member_id"];
            isOneToOne: false;
            referencedRelation: "project_area_member_candidates";
            referencedColumns: ["project_id", "id"];
          },
          {
            foreignKeyName: "notifications_recipient_project_member_fkey";
            columns: ["project_id", "recipient_project_member_id"];
            isOneToOne: false;
            referencedRelation: "project_members";
            referencedColumns: ["project_id", "id"];
          },
          {
            foreignKeyName: "notifications_recipient_project_member_fkey";
            columns: ["project_id", "recipient_project_member_id"];
            isOneToOne: false;
            referencedRelation: "work_assignment_candidates";
            referencedColumns: ["project_id", "id"];
          },
        ];
      };
      organizations: {
        Row: {
          created_at: string;
          id: string;
          legal_name: string | null;
          name: string;
          registration_code: string | null;
          status: string;
          tax_id: string | null;
          updated_at: string;
        };
        Insert: {
          created_at?: string;
          id?: string;
          legal_name?: string | null;
          name: string;
          registration_code?: string | null;
          status?: string;
          tax_id?: string | null;
          updated_at?: string;
        };
        Update: {
          created_at?: string;
          id?: string;
          legal_name?: string | null;
          name?: string;
          registration_code?: string | null;
          status?: string;
          tax_id?: string | null;
          updated_at?: string;
        };
        Relationships: [];
      };
      permissions: {
        Row: {
          created_at: string;
          description: string;
          id: string;
          key: string;
          status: string;
          updated_at: string;
        };
        Insert: {
          created_at?: string;
          description: string;
          id?: string;
          key: string;
          status?: string;
          updated_at?: string;
        };
        Update: {
          created_at?: string;
          description?: string;
          id?: string;
          key?: string;
          status?: string;
          updated_at?: string;
        };
        Relationships: [];
      };
      project_area_changes: {
        Row: {
          actor_project_member_id: string;
          actor_user_id: string;
          changed: boolean;
          code: string | null;
          command_id: string;
          command_name: string;
          description: string | null;
          name: string | null;
          occurred_at: string;
          project_area_id: string;
          project_id: string;
          project_member_area_id: string | null;
          project_member_id: string | null;
          reason: string | null;
        };
        Insert: {
          actor_project_member_id: string;
          actor_user_id: string;
          changed: boolean;
          code?: string | null;
          command_id: string;
          command_name: string;
          description?: string | null;
          name?: string | null;
          occurred_at?: string;
          project_area_id: string;
          project_id: string;
          project_member_area_id?: string | null;
          project_member_id?: string | null;
          reason?: string | null;
        };
        Update: {
          actor_project_member_id?: string;
          actor_user_id?: string;
          changed?: boolean;
          code?: string | null;
          command_id?: string;
          command_name?: string;
          description?: string | null;
          name?: string | null;
          occurred_at?: string;
          project_area_id?: string;
          project_id?: string;
          project_member_area_id?: string | null;
          project_member_id?: string | null;
          reason?: string | null;
        };
        Relationships: [
          {
            foreignKeyName: "project_area_changes_project_id_actor_project_member_id_fkey";
            columns: ["project_id", "actor_project_member_id"];
            isOneToOne: false;
            referencedRelation: "project_area_member_candidates";
            referencedColumns: ["project_id", "id"];
          },
          {
            foreignKeyName: "project_area_changes_project_id_actor_project_member_id_fkey";
            columns: ["project_id", "actor_project_member_id"];
            isOneToOne: false;
            referencedRelation: "project_members";
            referencedColumns: ["project_id", "id"];
          },
          {
            foreignKeyName: "project_area_changes_project_id_actor_project_member_id_fkey";
            columns: ["project_id", "actor_project_member_id"];
            isOneToOne: false;
            referencedRelation: "work_assignment_candidates";
            referencedColumns: ["project_id", "id"];
          },
          {
            foreignKeyName: "project_area_changes_project_id_fkey";
            columns: ["project_id"];
            isOneToOne: false;
            referencedRelation: "projects";
            referencedColumns: ["id"];
          },
          {
            foreignKeyName: "project_area_changes_project_id_project_area_id_fkey";
            columns: ["project_id", "project_area_id"];
            isOneToOne: false;
            referencedRelation: "daily_report_area_capabilities";
            referencedColumns: ["project_id", "id"];
          },
          {
            foreignKeyName: "project_area_changes_project_id_project_area_id_fkey";
            columns: ["project_id", "project_area_id"];
            isOneToOne: false;
            referencedRelation: "project_areas";
            referencedColumns: ["project_id", "id"];
          },
          {
            foreignKeyName: "project_area_changes_project_id_project_member_area_id_fkey";
            columns: ["project_id", "project_member_area_id"];
            isOneToOne: false;
            referencedRelation: "project_member_areas";
            referencedColumns: ["project_id", "id"];
          },
          {
            foreignKeyName: "project_area_changes_project_id_project_member_id_fkey";
            columns: ["project_id", "project_member_id"];
            isOneToOne: false;
            referencedRelation: "project_area_member_candidates";
            referencedColumns: ["project_id", "id"];
          },
          {
            foreignKeyName: "project_area_changes_project_id_project_member_id_fkey";
            columns: ["project_id", "project_member_id"];
            isOneToOne: false;
            referencedRelation: "project_members";
            referencedColumns: ["project_id", "id"];
          },
          {
            foreignKeyName: "project_area_changes_project_id_project_member_id_fkey";
            columns: ["project_id", "project_member_id"];
            isOneToOne: false;
            referencedRelation: "work_assignment_candidates";
            referencedColumns: ["project_id", "id"];
          },
        ];
      };
      project_areas: {
        Row: {
          code: string;
          created_at: string;
          created_by: string;
          description: string | null;
          id: string;
          name: string;
          project_id: string;
        };
        Insert: {
          code: string;
          created_at?: string;
          created_by: string;
          description?: string | null;
          id?: string;
          name: string;
          project_id: string;
        };
        Update: {
          code?: string;
          created_at?: string;
          created_by?: string;
          description?: string | null;
          id?: string;
          name?: string;
          project_id?: string;
        };
        Relationships: [
          {
            foreignKeyName: "project_areas_project_id_fkey";
            columns: ["project_id"];
            isOneToOne: false;
            referencedRelation: "projects";
            referencedColumns: ["id"];
          },
        ];
      };
      project_member_areas: {
        Row: {
          assigned_at: string;
          assigned_by: string;
          id: string;
          project_area_id: string;
          project_id: string;
          project_member_id: string;
          removal_reason: string | null;
          removed_at: string | null;
          removed_by: string | null;
        };
        Insert: {
          assigned_at?: string;
          assigned_by: string;
          id?: string;
          project_area_id: string;
          project_id: string;
          project_member_id: string;
          removal_reason?: string | null;
          removed_at?: string | null;
          removed_by?: string | null;
        };
        Update: {
          assigned_at?: string;
          assigned_by?: string;
          id?: string;
          project_area_id?: string;
          project_id?: string;
          project_member_id?: string;
          removal_reason?: string | null;
          removed_at?: string | null;
          removed_by?: string | null;
        };
        Relationships: [
          {
            foreignKeyName: "project_member_areas_project_id_fkey";
            columns: ["project_id"];
            isOneToOne: false;
            referencedRelation: "projects";
            referencedColumns: ["id"];
          },
          {
            foreignKeyName: "project_member_areas_project_id_project_area_id_fkey";
            columns: ["project_id", "project_area_id"];
            isOneToOne: false;
            referencedRelation: "daily_report_area_capabilities";
            referencedColumns: ["project_id", "id"];
          },
          {
            foreignKeyName: "project_member_areas_project_id_project_area_id_fkey";
            columns: ["project_id", "project_area_id"];
            isOneToOne: false;
            referencedRelation: "project_areas";
            referencedColumns: ["project_id", "id"];
          },
          {
            foreignKeyName: "project_member_areas_project_id_project_member_id_fkey";
            columns: ["project_id", "project_member_id"];
            isOneToOne: false;
            referencedRelation: "project_area_member_candidates";
            referencedColumns: ["project_id", "id"];
          },
          {
            foreignKeyName: "project_member_areas_project_id_project_member_id_fkey";
            columns: ["project_id", "project_member_id"];
            isOneToOne: false;
            referencedRelation: "project_members";
            referencedColumns: ["project_id", "id"];
          },
          {
            foreignKeyName: "project_member_areas_project_id_project_member_id_fkey";
            columns: ["project_id", "project_member_id"];
            isOneToOne: false;
            referencedRelation: "work_assignment_candidates";
            referencedColumns: ["project_id", "id"];
          },
        ];
      };
      project_member_roles: {
        Row: {
          created_at: string;
          id: string;
          project_id: string;
          project_member_id: string;
          role_id: string;
          status: string;
          updated_at: string;
        };
        Insert: {
          created_at?: string;
          id?: string;
          project_id: string;
          project_member_id: string;
          role_id: string;
          status?: string;
          updated_at?: string;
        };
        Update: {
          created_at?: string;
          id?: string;
          project_id?: string;
          project_member_id?: string;
          role_id?: string;
          status?: string;
          updated_at?: string;
        };
        Relationships: [
          {
            foreignKeyName: "project_member_roles_project_id_fkey";
            columns: ["project_id"];
            isOneToOne: false;
            referencedRelation: "projects";
            referencedColumns: ["id"];
          },
          {
            foreignKeyName: "project_member_roles_project_member_fkey";
            columns: ["project_id", "project_member_id"];
            isOneToOne: false;
            referencedRelation: "project_area_member_candidates";
            referencedColumns: ["project_id", "id"];
          },
          {
            foreignKeyName: "project_member_roles_project_member_fkey";
            columns: ["project_id", "project_member_id"];
            isOneToOne: false;
            referencedRelation: "project_members";
            referencedColumns: ["project_id", "id"];
          },
          {
            foreignKeyName: "project_member_roles_project_member_fkey";
            columns: ["project_id", "project_member_id"];
            isOneToOne: false;
            referencedRelation: "work_assignment_candidates";
            referencedColumns: ["project_id", "id"];
          },
          {
            foreignKeyName: "project_member_roles_role_id_fkey";
            columns: ["role_id"];
            isOneToOne: false;
            referencedRelation: "roles";
            referencedColumns: ["id"];
          },
        ];
      };
      project_members: {
        Row: {
          created_at: string;
          id: string;
          project_id: string;
          project_organization_id: string;
          status: string;
          updated_at: string;
          user_id: string;
        };
        Insert: {
          created_at?: string;
          id?: string;
          project_id: string;
          project_organization_id: string;
          status?: string;
          updated_at?: string;
          user_id: string;
        };
        Update: {
          created_at?: string;
          id?: string;
          project_id?: string;
          project_organization_id?: string;
          status?: string;
          updated_at?: string;
          user_id?: string;
        };
        Relationships: [
          {
            foreignKeyName: "project_members_project_id_fkey";
            columns: ["project_id"];
            isOneToOne: false;
            referencedRelation: "projects";
            referencedColumns: ["id"];
          },
          {
            foreignKeyName: "project_members_project_organization_fkey";
            columns: ["project_id", "project_organization_id"];
            isOneToOne: false;
            referencedRelation: "project_organizations";
            referencedColumns: ["project_id", "id"];
          },
        ];
      };
      project_organizations: {
        Row: {
          created_at: string;
          id: string;
          organization_id: string;
          project_id: string;
          relationship_type: string;
          status: string;
          updated_at: string;
        };
        Insert: {
          created_at?: string;
          id?: string;
          organization_id: string;
          project_id: string;
          relationship_type: string;
          status?: string;
          updated_at?: string;
        };
        Update: {
          created_at?: string;
          id?: string;
          organization_id?: string;
          project_id?: string;
          relationship_type?: string;
          status?: string;
          updated_at?: string;
        };
        Relationships: [
          {
            foreignKeyName: "project_organizations_organization_id_fkey";
            columns: ["organization_id"];
            isOneToOne: false;
            referencedRelation: "organizations";
            referencedColumns: ["id"];
          },
          {
            foreignKeyName: "project_organizations_project_id_fkey";
            columns: ["project_id"];
            isOneToOne: false;
            referencedRelation: "projects";
            referencedColumns: ["id"];
          },
        ];
      };
      projects: {
        Row: {
          code: string;
          created_at: string;
          description: string | null;
          end_date: string | null;
          id: string;
          name: string;
          start_date: string | null;
          status: string;
          updated_at: string;
        };
        Insert: {
          code: string;
          created_at?: string;
          description?: string | null;
          end_date?: string | null;
          id?: string;
          name: string;
          start_date?: string | null;
          status?: string;
          updated_at?: string;
        };
        Update: {
          code?: string;
          created_at?: string;
          description?: string | null;
          end_date?: string | null;
          id?: string;
          name?: string;
          start_date?: string | null;
          status?: string;
          updated_at?: string;
        };
        Relationships: [];
      };
      quality_inspection_commands: {
        Row: {
          actor_project_member_id: string;
          actor_user_id: string;
          command_id: string;
          created_at: string;
          inspection_id: string | null;
          inspection_request_id: string;
          operation: string;
          payload: Json;
          project_area_id: string;
          project_id: string;
          work_id: string;
        };
        Insert: {
          actor_project_member_id: string;
          actor_user_id: string;
          command_id: string;
          created_at?: string;
          inspection_id?: string | null;
          inspection_request_id: string;
          operation: string;
          payload: Json;
          project_area_id: string;
          project_id: string;
          work_id: string;
        };
        Update: {
          actor_project_member_id?: string;
          actor_user_id?: string;
          command_id?: string;
          created_at?: string;
          inspection_id?: string | null;
          inspection_request_id?: string;
          operation?: string;
          payload?: Json;
          project_area_id?: string;
          project_id?: string;
          work_id?: string;
        };
        Relationships: [
          {
            foreignKeyName: "quality_inspection_commands_actor_member_fkey";
            columns: ["project_id", "actor_project_member_id"];
            isOneToOne: false;
            referencedRelation: "project_area_member_candidates";
            referencedColumns: ["project_id", "id"];
          },
          {
            foreignKeyName: "quality_inspection_commands_actor_member_fkey";
            columns: ["project_id", "actor_project_member_id"];
            isOneToOne: false;
            referencedRelation: "project_members";
            referencedColumns: ["project_id", "id"];
          },
          {
            foreignKeyName: "quality_inspection_commands_actor_member_fkey";
            columns: ["project_id", "actor_project_member_id"];
            isOneToOne: false;
            referencedRelation: "work_assignment_candidates";
            referencedColumns: ["project_id", "id"];
          },
          {
            foreignKeyName: "quality_inspection_commands_area_fkey";
            columns: ["project_id", "project_area_id"];
            isOneToOne: false;
            referencedRelation: "daily_report_area_capabilities";
            referencedColumns: ["project_id", "id"];
          },
          {
            foreignKeyName: "quality_inspection_commands_area_fkey";
            columns: ["project_id", "project_area_id"];
            isOneToOne: false;
            referencedRelation: "project_areas";
            referencedColumns: ["project_id", "id"];
          },
          {
            foreignKeyName: "quality_inspection_commands_inspection_fkey";
            columns: ["project_id", "inspection_id"];
            isOneToOne: false;
            referencedRelation: "inspections";
            referencedColumns: ["project_id", "id"];
          },
          {
            foreignKeyName: "quality_inspection_commands_project_fkey";
            columns: ["project_id"];
            isOneToOne: false;
            referencedRelation: "projects";
            referencedColumns: ["id"];
          },
          {
            foreignKeyName: "quality_inspection_commands_request_fkey";
            columns: ["project_id", "inspection_request_id"];
            isOneToOne: false;
            referencedRelation: "inspection_requests";
            referencedColumns: ["project_id", "id"];
          },
          {
            foreignKeyName: "quality_inspection_commands_work_fkey";
            columns: ["project_id", "work_id"];
            isOneToOne: false;
            referencedRelation: "works";
            referencedColumns: ["project_id", "id"];
          },
        ];
      };
      role_permissions: {
        Row: {
          created_at: string;
          permission_id: string;
          role_id: string;
          scope_type: string;
        };
        Insert: {
          created_at?: string;
          permission_id: string;
          role_id: string;
          scope_type: string;
        };
        Update: {
          created_at?: string;
          permission_id?: string;
          role_id?: string;
          scope_type?: string;
        };
        Relationships: [
          {
            foreignKeyName: "role_permissions_permission_id_fkey";
            columns: ["permission_id"];
            isOneToOne: false;
            referencedRelation: "permissions";
            referencedColumns: ["id"];
          },
          {
            foreignKeyName: "role_permissions_role_id_fkey";
            columns: ["role_id"];
            isOneToOne: false;
            referencedRelation: "roles";
            referencedColumns: ["id"];
          },
        ];
      };
      roles: {
        Row: {
          code: string;
          created_at: string;
          description: string | null;
          id: string;
          name: string;
          status: string;
          updated_at: string;
        };
        Insert: {
          code: string;
          created_at?: string;
          description?: string | null;
          id?: string;
          name: string;
          status?: string;
          updated_at?: string;
        };
        Update: {
          code?: string;
          created_at?: string;
          description?: string | null;
          id?: string;
          name?: string;
          status?: string;
          updated_at?: string;
        };
        Relationships: [];
      };
      task_document_impacts: {
        Row: {
          created_at: string;
          document_impact_id: string;
          id: string;
          project_id: string;
          task_id: string;
        };
        Insert: {
          created_at?: string;
          document_impact_id: string;
          id?: string;
          project_id: string;
          task_id: string;
        };
        Update: {
          created_at?: string;
          document_impact_id?: string;
          id?: string;
          project_id?: string;
          task_id?: string;
        };
        Relationships: [
          {
            foreignKeyName: "task_document_impacts_document_impact_fkey";
            columns: ["project_id", "document_impact_id"];
            isOneToOne: true;
            referencedRelation: "document_impacts";
            referencedColumns: ["project_id", "id"];
          },
          {
            foreignKeyName: "task_document_impacts_project_id_fkey";
            columns: ["project_id"];
            isOneToOne: false;
            referencedRelation: "projects";
            referencedColumns: ["id"];
          },
          {
            foreignKeyName: "task_document_impacts_task_fkey";
            columns: ["project_id", "task_id"];
            isOneToOne: true;
            referencedRelation: "tasks";
            referencedColumns: ["project_id", "id"];
          },
        ];
      };
      tasks: {
        Row: {
          assignee_project_member_id: string | null;
          created_at: string;
          created_by: string | null;
          id: string;
          project_id: string;
          status: string;
          task_type: string;
          updated_at: string;
        };
        Insert: {
          assignee_project_member_id?: string | null;
          created_at?: string;
          created_by?: string | null;
          id?: string;
          project_id: string;
          status?: string;
          task_type: string;
          updated_at?: string;
        };
        Update: {
          assignee_project_member_id?: string | null;
          created_at?: string;
          created_by?: string | null;
          id?: string;
          project_id?: string;
          status?: string;
          task_type?: string;
          updated_at?: string;
        };
        Relationships: [
          {
            foreignKeyName: "tasks_assignee_project_member_fkey";
            columns: ["project_id", "assignee_project_member_id"];
            isOneToOne: false;
            referencedRelation: "project_area_member_candidates";
            referencedColumns: ["project_id", "id"];
          },
          {
            foreignKeyName: "tasks_assignee_project_member_fkey";
            columns: ["project_id", "assignee_project_member_id"];
            isOneToOne: false;
            referencedRelation: "project_members";
            referencedColumns: ["project_id", "id"];
          },
          {
            foreignKeyName: "tasks_assignee_project_member_fkey";
            columns: ["project_id", "assignee_project_member_id"];
            isOneToOne: false;
            referencedRelation: "work_assignment_candidates";
            referencedColumns: ["project_id", "id"];
          },
          {
            foreignKeyName: "tasks_project_id_fkey";
            columns: ["project_id"];
            isOneToOne: false;
            referencedRelation: "projects";
            referencedColumns: ["id"];
          },
        ];
      };
      technical_documents: {
        Row: {
          code: string;
          created_at: string;
          created_by: string;
          id: string;
          project_id: string;
          title: string;
          updated_at: string;
        };
        Insert: {
          code: string;
          created_at?: string;
          created_by: string;
          id?: string;
          project_id: string;
          title: string;
          updated_at?: string;
        };
        Update: {
          code?: string;
          created_at?: string;
          created_by?: string;
          id?: string;
          project_id?: string;
          title?: string;
          updated_at?: string;
        };
        Relationships: [
          {
            foreignKeyName: "technical_documents_project_id_fkey";
            columns: ["project_id"];
            isOneToOne: false;
            referencedRelation: "projects";
            referencedColumns: ["id"];
          },
        ];
      };
      work_assignment_changes: {
        Row: {
          actor_project_member_id: string;
          actor_user_id: string;
          changed: boolean;
          command_id: string;
          command_name: string;
          expected_current_assignment_id: string | null;
          from_project_member_id: string | null;
          occurred_at: string;
          project_id: string;
          reason: string | null;
          result_assignment_id: string;
          to_project_member_id: string;
          work_id: string;
        };
        Insert: {
          actor_project_member_id: string;
          actor_user_id: string;
          changed: boolean;
          command_id: string;
          command_name: string;
          expected_current_assignment_id?: string | null;
          from_project_member_id?: string | null;
          occurred_at?: string;
          project_id: string;
          reason?: string | null;
          result_assignment_id: string;
          to_project_member_id: string;
          work_id: string;
        };
        Update: {
          actor_project_member_id?: string;
          actor_user_id?: string;
          changed?: boolean;
          command_id?: string;
          command_name?: string;
          expected_current_assignment_id?: string | null;
          from_project_member_id?: string | null;
          occurred_at?: string;
          project_id?: string;
          reason?: string | null;
          result_assignment_id?: string;
          to_project_member_id?: string;
          work_id?: string;
        };
        Relationships: [
          {
            foreignKeyName: "work_assignment_changes_project_id_actor_project_member_id_fkey";
            columns: ["project_id", "actor_project_member_id"];
            isOneToOne: false;
            referencedRelation: "project_area_member_candidates";
            referencedColumns: ["project_id", "id"];
          },
          {
            foreignKeyName: "work_assignment_changes_project_id_actor_project_member_id_fkey";
            columns: ["project_id", "actor_project_member_id"];
            isOneToOne: false;
            referencedRelation: "project_members";
            referencedColumns: ["project_id", "id"];
          },
          {
            foreignKeyName: "work_assignment_changes_project_id_actor_project_member_id_fkey";
            columns: ["project_id", "actor_project_member_id"];
            isOneToOne: false;
            referencedRelation: "work_assignment_candidates";
            referencedColumns: ["project_id", "id"];
          },
          {
            foreignKeyName: "work_assignment_changes_project_id_expected_current_assign_fkey";
            columns: ["project_id", "expected_current_assignment_id"];
            isOneToOne: false;
            referencedRelation: "work_assignments";
            referencedColumns: ["project_id", "id"];
          },
          {
            foreignKeyName: "work_assignment_changes_project_id_fkey";
            columns: ["project_id"];
            isOneToOne: false;
            referencedRelation: "projects";
            referencedColumns: ["id"];
          },
          {
            foreignKeyName: "work_assignment_changes_project_id_from_project_member_id_fkey";
            columns: ["project_id", "from_project_member_id"];
            isOneToOne: false;
            referencedRelation: "project_area_member_candidates";
            referencedColumns: ["project_id", "id"];
          },
          {
            foreignKeyName: "work_assignment_changes_project_id_from_project_member_id_fkey";
            columns: ["project_id", "from_project_member_id"];
            isOneToOne: false;
            referencedRelation: "project_members";
            referencedColumns: ["project_id", "id"];
          },
          {
            foreignKeyName: "work_assignment_changes_project_id_from_project_member_id_fkey";
            columns: ["project_id", "from_project_member_id"];
            isOneToOne: false;
            referencedRelation: "work_assignment_candidates";
            referencedColumns: ["project_id", "id"];
          },
          {
            foreignKeyName: "work_assignment_changes_project_id_result_assignment_id_fkey";
            columns: ["project_id", "result_assignment_id"];
            isOneToOne: false;
            referencedRelation: "work_assignments";
            referencedColumns: ["project_id", "id"];
          },
          {
            foreignKeyName: "work_assignment_changes_project_id_to_project_member_id_fkey";
            columns: ["project_id", "to_project_member_id"];
            isOneToOne: false;
            referencedRelation: "project_area_member_candidates";
            referencedColumns: ["project_id", "id"];
          },
          {
            foreignKeyName: "work_assignment_changes_project_id_to_project_member_id_fkey";
            columns: ["project_id", "to_project_member_id"];
            isOneToOne: false;
            referencedRelation: "project_members";
            referencedColumns: ["project_id", "id"];
          },
          {
            foreignKeyName: "work_assignment_changes_project_id_to_project_member_id_fkey";
            columns: ["project_id", "to_project_member_id"];
            isOneToOne: false;
            referencedRelation: "work_assignment_candidates";
            referencedColumns: ["project_id", "id"];
          },
          {
            foreignKeyName: "work_assignment_changes_project_id_work_id_fkey";
            columns: ["project_id", "work_id"];
            isOneToOne: false;
            referencedRelation: "works";
            referencedColumns: ["project_id", "id"];
          },
        ];
      };
      work_assignments: {
        Row: {
          assigned_at: string;
          assigned_by: string;
          assignment_change_id: string | null;
          assignment_reason: string | null;
          end_reason: string | null;
          ended_at: string | null;
          ended_by: string | null;
          id: string;
          project_id: string;
          project_member_id: string;
          work_id: string;
        };
        Insert: {
          assigned_at?: string;
          assigned_by: string;
          assignment_change_id?: string | null;
          assignment_reason?: string | null;
          end_reason?: string | null;
          ended_at?: string | null;
          ended_by?: string | null;
          id?: string;
          project_id: string;
          project_member_id: string;
          work_id: string;
        };
        Update: {
          assigned_at?: string;
          assigned_by?: string;
          assignment_change_id?: string | null;
          assignment_reason?: string | null;
          end_reason?: string | null;
          ended_at?: string | null;
          ended_by?: string | null;
          id?: string;
          project_id?: string;
          project_member_id?: string;
          work_id?: string;
        };
        Relationships: [
          {
            foreignKeyName: "work_assignments_project_id_assignment_change_id_fkey";
            columns: ["project_id", "assignment_change_id"];
            isOneToOne: false;
            referencedRelation: "work_assignment_changes";
            referencedColumns: ["project_id", "command_id"];
          },
          {
            foreignKeyName: "work_assignments_project_id_fkey";
            columns: ["project_id"];
            isOneToOne: false;
            referencedRelation: "projects";
            referencedColumns: ["id"];
          },
          {
            foreignKeyName: "work_assignments_project_member_fkey";
            columns: ["project_id", "project_member_id"];
            isOneToOne: false;
            referencedRelation: "project_area_member_candidates";
            referencedColumns: ["project_id", "id"];
          },
          {
            foreignKeyName: "work_assignments_project_member_fkey";
            columns: ["project_id", "project_member_id"];
            isOneToOne: false;
            referencedRelation: "project_members";
            referencedColumns: ["project_id", "id"];
          },
          {
            foreignKeyName: "work_assignments_project_member_fkey";
            columns: ["project_id", "project_member_id"];
            isOneToOne: false;
            referencedRelation: "work_assignment_candidates";
            referencedColumns: ["project_id", "id"];
          },
          {
            foreignKeyName: "work_assignments_work_fkey";
            columns: ["project_id", "work_id"];
            isOneToOne: false;
            referencedRelation: "works";
            referencedColumns: ["project_id", "id"];
          },
        ];
      };
      work_blocker_commands: {
        Row: {
          actor_project_member_id: string;
          actor_user_id: string;
          category: string | null;
          command_id: string;
          description: string | null;
          occurred_at: string;
          operation: string;
          project_id: string;
          resolution_note: string | null;
          title: string | null;
          work_blocker_id: string;
          work_id: string;
        };
        Insert: {
          actor_project_member_id: string;
          actor_user_id: string;
          category?: string | null;
          command_id: string;
          description?: string | null;
          occurred_at?: string;
          operation: string;
          project_id: string;
          resolution_note?: string | null;
          title?: string | null;
          work_blocker_id: string;
          work_id: string;
        };
        Update: {
          actor_project_member_id?: string;
          actor_user_id?: string;
          category?: string | null;
          command_id?: string;
          description?: string | null;
          occurred_at?: string;
          operation?: string;
          project_id?: string;
          resolution_note?: string | null;
          title?: string | null;
          work_blocker_id?: string;
          work_id?: string;
        };
        Relationships: [
          {
            foreignKeyName: "work_blocker_commands_actor_member_fkey";
            columns: ["project_id", "actor_project_member_id"];
            isOneToOne: false;
            referencedRelation: "project_area_member_candidates";
            referencedColumns: ["project_id", "id"];
          },
          {
            foreignKeyName: "work_blocker_commands_actor_member_fkey";
            columns: ["project_id", "actor_project_member_id"];
            isOneToOne: false;
            referencedRelation: "project_members";
            referencedColumns: ["project_id", "id"];
          },
          {
            foreignKeyName: "work_blocker_commands_actor_member_fkey";
            columns: ["project_id", "actor_project_member_id"];
            isOneToOne: false;
            referencedRelation: "work_assignment_candidates";
            referencedColumns: ["project_id", "id"];
          },
          {
            foreignKeyName: "work_blocker_commands_blocker_fkey";
            columns: ["project_id", "work_blocker_id"];
            isOneToOne: false;
            referencedRelation: "work_blockers";
            referencedColumns: ["project_id", "id"];
          },
          {
            foreignKeyName: "work_blocker_commands_work_fkey";
            columns: ["project_id", "work_id"];
            isOneToOne: false;
            referencedRelation: "works";
            referencedColumns: ["project_id", "id"];
          },
        ];
      };
      work_blockers: {
        Row: {
          category: string;
          created_at: string;
          description: string;
          id: string;
          opened_at: string;
          opened_by_project_member_id: string;
          project_id: string;
          resolution_note: string | null;
          resolved_at: string | null;
          resolved_by_project_member_id: string | null;
          status: string;
          title: string;
          updated_at: string;
          work_id: string;
        };
        Insert: {
          category: string;
          created_at?: string;
          description: string;
          id?: string;
          opened_at?: string;
          opened_by_project_member_id: string;
          project_id: string;
          resolution_note?: string | null;
          resolved_at?: string | null;
          resolved_by_project_member_id?: string | null;
          status?: string;
          title: string;
          updated_at?: string;
          work_id: string;
        };
        Update: {
          category?: string;
          created_at?: string;
          description?: string;
          id?: string;
          opened_at?: string;
          opened_by_project_member_id?: string;
          project_id?: string;
          resolution_note?: string | null;
          resolved_at?: string | null;
          resolved_by_project_member_id?: string | null;
          status?: string;
          title?: string;
          updated_at?: string;
          work_id?: string;
        };
        Relationships: [
          {
            foreignKeyName: "work_blockers_opened_by_fkey";
            columns: ["project_id", "opened_by_project_member_id"];
            isOneToOne: false;
            referencedRelation: "project_area_member_candidates";
            referencedColumns: ["project_id", "id"];
          },
          {
            foreignKeyName: "work_blockers_opened_by_fkey";
            columns: ["project_id", "opened_by_project_member_id"];
            isOneToOne: false;
            referencedRelation: "project_members";
            referencedColumns: ["project_id", "id"];
          },
          {
            foreignKeyName: "work_blockers_opened_by_fkey";
            columns: ["project_id", "opened_by_project_member_id"];
            isOneToOne: false;
            referencedRelation: "work_assignment_candidates";
            referencedColumns: ["project_id", "id"];
          },
          {
            foreignKeyName: "work_blockers_project_id_fkey";
            columns: ["project_id"];
            isOneToOne: false;
            referencedRelation: "projects";
            referencedColumns: ["id"];
          },
          {
            foreignKeyName: "work_blockers_resolved_by_fkey";
            columns: ["project_id", "resolved_by_project_member_id"];
            isOneToOne: false;
            referencedRelation: "project_area_member_candidates";
            referencedColumns: ["project_id", "id"];
          },
          {
            foreignKeyName: "work_blockers_resolved_by_fkey";
            columns: ["project_id", "resolved_by_project_member_id"];
            isOneToOne: false;
            referencedRelation: "project_members";
            referencedColumns: ["project_id", "id"];
          },
          {
            foreignKeyName: "work_blockers_resolved_by_fkey";
            columns: ["project_id", "resolved_by_project_member_id"];
            isOneToOne: false;
            referencedRelation: "work_assignment_candidates";
            referencedColumns: ["project_id", "id"];
          },
          {
            foreignKeyName: "work_blockers_work_fkey";
            columns: ["project_id", "work_id"];
            isOneToOne: false;
            referencedRelation: "works";
            referencedColumns: ["project_id", "id"];
          },
        ];
      };
      work_dependencies: {
        Row: {
          created_at: string;
          created_by: string;
          dependent_work_id: string;
          depends_on_work_id: string;
          id: string;
          project_id: string;
          removed_at: string | null;
          removed_by: string | null;
        };
        Insert: {
          created_at?: string;
          created_by: string;
          dependent_work_id: string;
          depends_on_work_id: string;
          id?: string;
          project_id: string;
          removed_at?: string | null;
          removed_by?: string | null;
        };
        Update: {
          created_at?: string;
          created_by?: string;
          dependent_work_id?: string;
          depends_on_work_id?: string;
          id?: string;
          project_id?: string;
          removed_at?: string | null;
          removed_by?: string | null;
        };
        Relationships: [
          {
            foreignKeyName: "work_dependencies_dependent_work_fkey";
            columns: ["project_id", "dependent_work_id"];
            isOneToOne: false;
            referencedRelation: "works";
            referencedColumns: ["project_id", "id"];
          },
          {
            foreignKeyName: "work_dependencies_depends_on_work_fkey";
            columns: ["project_id", "depends_on_work_id"];
            isOneToOne: false;
            referencedRelation: "works";
            referencedColumns: ["project_id", "id"];
          },
          {
            foreignKeyName: "work_dependencies_project_id_fkey";
            columns: ["project_id"];
            isOneToOne: false;
            referencedRelation: "projects";
            referencedColumns: ["id"];
          },
        ];
      };
      work_progress_changes: {
        Row: {
          actor_project_member_id: string;
          actor_user_id: string;
          command_id: string;
          note: string | null;
          occurred_at: string;
          project_area_id: string;
          project_id: string;
          quantity: number;
          recorded_for_date: string;
          work_id: string;
          work_progress_entry_id: string;
        };
        Insert: {
          actor_project_member_id: string;
          actor_user_id: string;
          command_id: string;
          note?: string | null;
          occurred_at?: string;
          project_area_id: string;
          project_id: string;
          quantity: number;
          recorded_for_date: string;
          work_id: string;
          work_progress_entry_id: string;
        };
        Update: {
          actor_project_member_id?: string;
          actor_user_id?: string;
          command_id?: string;
          note?: string | null;
          occurred_at?: string;
          project_area_id?: string;
          project_id?: string;
          quantity?: number;
          recorded_for_date?: string;
          work_id?: string;
          work_progress_entry_id?: string;
        };
        Relationships: [
          {
            foreignKeyName: "work_progress_changes_project_id_actor_project_member_id_fkey";
            columns: ["project_id", "actor_project_member_id"];
            isOneToOne: false;
            referencedRelation: "project_area_member_candidates";
            referencedColumns: ["project_id", "id"];
          },
          {
            foreignKeyName: "work_progress_changes_project_id_actor_project_member_id_fkey";
            columns: ["project_id", "actor_project_member_id"];
            isOneToOne: false;
            referencedRelation: "project_members";
            referencedColumns: ["project_id", "id"];
          },
          {
            foreignKeyName: "work_progress_changes_project_id_actor_project_member_id_fkey";
            columns: ["project_id", "actor_project_member_id"];
            isOneToOne: false;
            referencedRelation: "work_assignment_candidates";
            referencedColumns: ["project_id", "id"];
          },
          {
            foreignKeyName: "work_progress_changes_project_id_project_area_id_fkey";
            columns: ["project_id", "project_area_id"];
            isOneToOne: false;
            referencedRelation: "daily_report_area_capabilities";
            referencedColumns: ["project_id", "id"];
          },
          {
            foreignKeyName: "work_progress_changes_project_id_project_area_id_fkey";
            columns: ["project_id", "project_area_id"];
            isOneToOne: false;
            referencedRelation: "project_areas";
            referencedColumns: ["project_id", "id"];
          },
          {
            foreignKeyName: "work_progress_changes_project_id_work_id_fkey";
            columns: ["project_id", "work_id"];
            isOneToOne: false;
            referencedRelation: "works";
            referencedColumns: ["project_id", "id"];
          },
          {
            foreignKeyName: "work_progress_changes_project_id_work_progress_entry_id_fkey";
            columns: ["project_id", "work_progress_entry_id"];
            isOneToOne: false;
            referencedRelation: "work_progress_entries";
            referencedColumns: ["project_id", "id"];
          },
        ];
      };
      work_progress_decisions: {
        Row: {
          actor_project_member_id: string;
          actor_user_id: string;
          command_id: string;
          decision: string;
          occurred_at: string;
          project_area_id: string;
          project_id: string;
          reason: string | null;
          work_id: string;
          work_progress_entry_id: string;
        };
        Insert: {
          actor_project_member_id: string;
          actor_user_id: string;
          command_id: string;
          decision: string;
          occurred_at?: string;
          project_area_id: string;
          project_id: string;
          reason?: string | null;
          work_id: string;
          work_progress_entry_id: string;
        };
        Update: {
          actor_project_member_id?: string;
          actor_user_id?: string;
          command_id?: string;
          decision?: string;
          occurred_at?: string;
          project_area_id?: string;
          project_id?: string;
          reason?: string | null;
          work_id?: string;
          work_progress_entry_id?: string;
        };
        Relationships: [
          {
            foreignKeyName: "work_progress_decisions_project_id_actor_project_member_id_fkey";
            columns: ["project_id", "actor_project_member_id"];
            isOneToOne: false;
            referencedRelation: "project_area_member_candidates";
            referencedColumns: ["project_id", "id"];
          },
          {
            foreignKeyName: "work_progress_decisions_project_id_actor_project_member_id_fkey";
            columns: ["project_id", "actor_project_member_id"];
            isOneToOne: false;
            referencedRelation: "project_members";
            referencedColumns: ["project_id", "id"];
          },
          {
            foreignKeyName: "work_progress_decisions_project_id_actor_project_member_id_fkey";
            columns: ["project_id", "actor_project_member_id"];
            isOneToOne: false;
            referencedRelation: "work_assignment_candidates";
            referencedColumns: ["project_id", "id"];
          },
          {
            foreignKeyName: "work_progress_decisions_project_id_fkey";
            columns: ["project_id"];
            isOneToOne: false;
            referencedRelation: "projects";
            referencedColumns: ["id"];
          },
          {
            foreignKeyName: "work_progress_decisions_project_id_project_area_id_fkey";
            columns: ["project_id", "project_area_id"];
            isOneToOne: false;
            referencedRelation: "daily_report_area_capabilities";
            referencedColumns: ["project_id", "id"];
          },
          {
            foreignKeyName: "work_progress_decisions_project_id_project_area_id_fkey";
            columns: ["project_id", "project_area_id"];
            isOneToOne: false;
            referencedRelation: "project_areas";
            referencedColumns: ["project_id", "id"];
          },
          {
            foreignKeyName: "work_progress_decisions_project_id_work_id_fkey";
            columns: ["project_id", "work_id"];
            isOneToOne: false;
            referencedRelation: "works";
            referencedColumns: ["project_id", "id"];
          },
          {
            foreignKeyName: "work_progress_decisions_project_id_work_progress_entry_id_fkey";
            columns: ["project_id", "work_progress_entry_id"];
            isOneToOne: true;
            referencedRelation: "work_progress_entries";
            referencedColumns: ["project_id", "id"];
          },
        ];
      };
      work_progress_entries: {
        Row: {
          confirmation_status: string;
          confirmed_at: string | null;
          confirmed_by: string | null;
          created_at: string;
          created_by: string;
          daily_report_id: string | null;
          id: string;
          note: string | null;
          project_id: string;
          quantity: number;
          return_reason: string | null;
          returned_at: string | null;
          returned_by: string | null;
          work_date: string;
          work_id: string;
        };
        Insert: {
          confirmation_status?: string;
          confirmed_at?: string | null;
          confirmed_by?: string | null;
          created_at?: string;
          created_by: string;
          daily_report_id?: string | null;
          id?: string;
          note?: string | null;
          project_id: string;
          quantity: number;
          return_reason?: string | null;
          returned_at?: string | null;
          returned_by?: string | null;
          work_date: string;
          work_id: string;
        };
        Update: {
          confirmation_status?: string;
          confirmed_at?: string | null;
          confirmed_by?: string | null;
          created_at?: string;
          created_by?: string;
          daily_report_id?: string | null;
          id?: string;
          note?: string | null;
          project_id?: string;
          quantity?: number;
          return_reason?: string | null;
          returned_at?: string | null;
          returned_by?: string | null;
          work_date?: string;
          work_id?: string;
        };
        Relationships: [
          {
            foreignKeyName: "work_progress_entries_project_id_daily_report_id_fkey";
            columns: ["project_id", "daily_report_id"];
            isOneToOne: false;
            referencedRelation: "daily_reports";
            referencedColumns: ["project_id", "id"];
          },
          {
            foreignKeyName: "work_progress_entries_project_id_fkey";
            columns: ["project_id"];
            isOneToOne: false;
            referencedRelation: "projects";
            referencedColumns: ["id"];
          },
          {
            foreignKeyName: "work_progress_entries_work_fkey";
            columns: ["project_id", "work_id"];
            isOneToOne: false;
            referencedRelation: "works";
            referencedColumns: ["project_id", "id"];
          },
        ];
      };
      works: {
        Row: {
          code: string;
          created_at: string;
          created_by: string;
          description: string | null;
          id: string;
          planned_finish_date: string | null;
          planned_quantity: number | null;
          planned_start_date: string | null;
          project_area_id: string | null;
          project_id: string;
          status: string;
          title: string;
          unit: string | null;
          updated_at: string;
        };
        Insert: {
          code: string;
          created_at?: string;
          created_by: string;
          description?: string | null;
          id?: string;
          planned_finish_date?: string | null;
          planned_quantity?: number | null;
          planned_start_date?: string | null;
          project_area_id?: string | null;
          project_id: string;
          status?: string;
          title: string;
          unit?: string | null;
          updated_at?: string;
        };
        Update: {
          code?: string;
          created_at?: string;
          created_by?: string;
          description?: string | null;
          id?: string;
          planned_finish_date?: string | null;
          planned_quantity?: number | null;
          planned_start_date?: string | null;
          project_area_id?: string | null;
          project_id?: string;
          status?: string;
          title?: string;
          unit?: string | null;
          updated_at?: string;
        };
        Relationships: [
          {
            foreignKeyName: "works_project_area_fkey";
            columns: ["project_id", "project_area_id"];
            isOneToOne: false;
            referencedRelation: "daily_report_area_capabilities";
            referencedColumns: ["project_id", "id"];
          },
          {
            foreignKeyName: "works_project_area_fkey";
            columns: ["project_id", "project_area_id"];
            isOneToOne: false;
            referencedRelation: "project_areas";
            referencedColumns: ["project_id", "id"];
          },
          {
            foreignKeyName: "works_project_id_fkey";
            columns: ["project_id"];
            isOneToOne: false;
            referencedRelation: "projects";
            referencedColumns: ["id"];
          },
        ];
      };
    };
    Views: {
      daily_report_area_capabilities: {
        Row: {
          can_confirm: boolean | null;
          can_report: boolean | null;
          code: string | null;
          id: string | null;
          name: string | null;
          project_id: string | null;
        };
        Insert: {
          can_confirm?: never;
          can_report?: never;
          code?: string | null;
          id?: string | null;
          name?: string | null;
          project_id?: string | null;
        };
        Update: {
          can_confirm?: never;
          can_report?: never;
          code?: string | null;
          id?: string | null;
          name?: string | null;
          project_id?: string | null;
        };
        Relationships: [
          {
            foreignKeyName: "project_areas_project_id_fkey";
            columns: ["project_id"];
            isOneToOne: false;
            referencedRelation: "projects";
            referencedColumns: ["id"];
          },
        ];
      };
      project_area_member_candidates: {
        Row: {
          id: string | null;
          project_id: string | null;
        };
        Relationships: [
          {
            foreignKeyName: "project_members_project_id_fkey";
            columns: ["project_id"];
            isOneToOne: false;
            referencedRelation: "projects";
            referencedColumns: ["id"];
          },
        ];
      };
      work_assignment_candidates: {
        Row: {
          id: string | null;
          project_id: string | null;
        };
        Relationships: [
          {
            foreignKeyName: "project_members_project_id_fkey";
            columns: ["project_id"];
            isOneToOne: false;
            referencedRelation: "projects";
            referencedColumns: ["id"];
          },
        ];
      };
    };
    Functions: {
      accept_work: {
        Args: { p_project_id: string; p_work_id: string };
        Returns: string;
      };
      accept_work_inspection: {
        Args: {
          p_command_id: string;
          p_inspection_id: string;
          p_result_note: string;
        };
        Returns: string;
      };
      acknowledge_own_document_impact: {
        Args: { notification_id: string };
        Returns: string;
      };
      add_daily_report_progress: {
        Args: {
          p_command_id: string;
          p_daily_report_id: string;
          p_note: string;
          p_quantity: number;
          p_work_id: string;
        };
        Returns: string;
      };
      assign_project_member_area: {
        Args: {
          p_command_id: string;
          p_project_area_id: string;
          p_project_member_id: string;
          p_reason?: string;
        };
        Returns: string;
      };
      assign_work: {
        Args: {
          p_command_id: string;
          p_new_project_member_id: string;
          p_reason?: string;
          p_work_id: string;
        };
        Returns: string;
      };
      block_work: {
        Args: { p_project_id: string; p_work_id: string };
        Returns: string;
      };
      close_work: {
        Args: { p_project_id: string; p_work_id: string };
        Returns: string;
      };
      confirm_daily_report: {
        Args: { p_command_id: string; p_daily_report_id: string };
        Returns: string;
      };
      confirm_work_progress: {
        Args: { p_command_id: string; p_work_progress_entry_id: string };
        Returns: string;
      };
      create_daily_report: {
        Args: {
          p_command_id: string;
          p_problems: string;
          p_project_area_id: string;
          p_report_date: string;
          p_summary: string;
          p_workers_count: number;
        };
        Returns: string;
      };
      create_project_area: {
        Args: {
          p_code: string;
          p_command_id: string;
          p_description: string;
          p_name: string;
          p_project_id: string;
        };
        Returns: string;
      };
      get_own_vertical_slice: {
        Args: { notification_id: string };
        Returns: {
          acknowledged_at: string;
          acknowledgement_id: string;
          detected_at: string;
          document_code: string;
          document_title: string;
          impact_status: string;
          issue_state: string;
          issued_at: string;
          member_role_codes: string;
          notification_created_at: string;
          notification_read_at: string;
          project_code: string;
          project_name: string;
          responsible_email: string;
          revision_code: string;
          revision_status: string;
          task_status: string;
          task_type: string;
          work_code: string;
          work_status: string;
          work_title: string;
        }[];
      };
      get_own_vertical_slice_audit: {
        Args: { notification_id: string };
        Returns: {
          action_key: string;
          occurred_at: string;
        }[];
      };
      get_work_readiness: { Args: { p_work_id: string }; Returns: Json };
      issue_document_revision_for_work: {
        Args: {
          p_document_revision_id: string;
          p_project_id: string;
          p_technical_document_id: string;
        };
        Returns: string;
      };
      mark_own_notification_read: {
        Args: { notification_id: string };
        Returns: string;
      };
      mark_work_ready: {
        Args: { p_project_id: string; p_work_id: string };
        Returns: string;
      };
      mark_work_ready_for_inspection: {
        Args: { p_project_id: string; p_work_id: string };
        Returns: string;
      };
      open_work_blocker: {
        Args: {
          p_category: string;
          p_command_id: string;
          p_description: string;
          p_title: string;
          p_work_id: string;
        };
        Returns: string;
      };
      reassign_work: {
        Args: {
          p_command_id: string;
          p_expected_current_assignment_id: string;
          p_new_project_member_id: string;
          p_reason: string;
          p_work_id: string;
        };
        Returns: string;
      };
      remove_project_member_area: {
        Args: {
          p_command_id: string;
          p_project_member_area_id: string;
          p_reason: string;
        };
        Returns: string;
      };
      report_work_progress: {
        Args: {
          p_command_id: string;
          p_note: string;
          p_quantity: number;
          p_recorded_for_date: string;
          p_work_id: string;
        };
        Returns: string;
      };
      request_work_inspection: {
        Args: { p_command_id: string; p_work_id: string };
        Returns: string;
      };
      require_work_rework: {
        Args: { p_project_id: string; p_work_id: string };
        Returns: string;
      };
      resolve_work_blocker: {
        Args: {
          p_command_id: string;
          p_resolution_note: string;
          p_work_blocker_id: string;
        };
        Returns: string;
      };
      resume_blocked_work: {
        Args: { p_project_id: string; p_work_id: string };
        Returns: string;
      };
      return_daily_report: {
        Args: {
          p_command_id: string;
          p_daily_report_id: string;
          p_return_reason: string;
        };
        Returns: string;
      };
      return_work_progress: {
        Args: {
          p_command_id: string;
          p_reason: string;
          p_work_progress_entry_id: string;
        };
        Returns: string;
      };
      schedule_work_inspection: {
        Args: { p_command_id: string; p_inspection_request_id: string };
        Returns: string;
      };
      start_work: {
        Args: { p_project_id: string; p_work_id: string };
        Returns: string;
      };
      start_work_inspection: {
        Args: { p_command_id: string; p_inspection_id: string };
        Returns: string;
      };
      submit_daily_report: {
        Args: { p_command_id: string; p_daily_report_id: string };
        Returns: string;
      };
      update_daily_report_draft: {
        Args: {
          p_command_id: string;
          p_daily_report_id: string;
          p_problems: string;
          p_summary: string;
          p_workers_count: number;
        };
        Returns: string;
      };
      update_project_area: {
        Args: {
          p_command_id: string;
          p_description: string;
          p_name: string;
          p_project_area_id: string;
        };
        Returns: string;
      };
    };
    Enums: {
      [_ in never]: never;
    };
    CompositeTypes: {
      [_ in never]: never;
    };
  };
};

type DatabaseWithoutInternals = Omit<Database, "__InternalSupabase">;

type DefaultSchema = DatabaseWithoutInternals[Extract<
  keyof Database,
  "public"
>];

export type Tables<
  DefaultSchemaTableNameOrOptions extends
    | keyof (DefaultSchema["Tables"] & DefaultSchema["Views"])
    | { schema: keyof DatabaseWithoutInternals },
  TableName extends (DefaultSchemaTableNameOrOptions extends {
    schema: keyof DatabaseWithoutInternals;
  }
    ? keyof (DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Tables"] &
        DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Views"])
    : never) = never,
> = DefaultSchemaTableNameOrOptions extends {
  schema: keyof DatabaseWithoutInternals;
}
  ? (DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Tables"] &
      DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Views"])[TableName] extends {
      Row: infer R;
    }
    ? R
    : never
  : DefaultSchemaTableNameOrOptions extends keyof (DefaultSchema["Tables"] &
        DefaultSchema["Views"])
    ? (DefaultSchema["Tables"] &
        DefaultSchema["Views"])[DefaultSchemaTableNameOrOptions] extends {
        Row: infer R;
      }
      ? R
      : never
    : never;

export type TablesInsert<
  DefaultSchemaTableNameOrOptions extends
    keyof DefaultSchema["Tables"] | { schema: keyof DatabaseWithoutInternals },
  TableName extends (DefaultSchemaTableNameOrOptions extends {
    schema: keyof DatabaseWithoutInternals;
  }
    ? keyof DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Tables"]
    : never) = never,
> = DefaultSchemaTableNameOrOptions extends {
  schema: keyof DatabaseWithoutInternals;
}
  ? DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Tables"][TableName] extends {
      Insert: infer I;
    }
    ? I
    : never
  : DefaultSchemaTableNameOrOptions extends keyof DefaultSchema["Tables"]
    ? DefaultSchema["Tables"][DefaultSchemaTableNameOrOptions] extends {
        Insert: infer I;
      }
      ? I
      : never
    : never;

export type TablesUpdate<
  DefaultSchemaTableNameOrOptions extends
    keyof DefaultSchema["Tables"] | { schema: keyof DatabaseWithoutInternals },
  TableName extends (DefaultSchemaTableNameOrOptions extends {
    schema: keyof DatabaseWithoutInternals;
  }
    ? keyof DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Tables"]
    : never) = never,
> = DefaultSchemaTableNameOrOptions extends {
  schema: keyof DatabaseWithoutInternals;
}
  ? DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Tables"][TableName] extends {
      Update: infer U;
    }
    ? U
    : never
  : DefaultSchemaTableNameOrOptions extends keyof DefaultSchema["Tables"]
    ? DefaultSchema["Tables"][DefaultSchemaTableNameOrOptions] extends {
        Update: infer U;
      }
      ? U
      : never
    : never;

export type Enums<
  DefaultSchemaEnumNameOrOptions extends
    keyof DefaultSchema["Enums"] | { schema: keyof DatabaseWithoutInternals },
  EnumName extends (DefaultSchemaEnumNameOrOptions extends {
    schema: keyof DatabaseWithoutInternals;
  }
    ? keyof DatabaseWithoutInternals[DefaultSchemaEnumNameOrOptions["schema"]]["Enums"]
    : never) = never,
> = DefaultSchemaEnumNameOrOptions extends {
  schema: keyof DatabaseWithoutInternals;
}
  ? DatabaseWithoutInternals[DefaultSchemaEnumNameOrOptions["schema"]]["Enums"][EnumName]
  : DefaultSchemaEnumNameOrOptions extends keyof DefaultSchema["Enums"]
    ? DefaultSchema["Enums"][DefaultSchemaEnumNameOrOptions]
    : never;

export type CompositeTypes<
  PublicCompositeTypeNameOrOptions extends
    | keyof DefaultSchema["CompositeTypes"]
    | { schema: keyof DatabaseWithoutInternals },
  CompositeTypeName extends (PublicCompositeTypeNameOrOptions extends {
    schema: keyof DatabaseWithoutInternals;
  }
    ? keyof DatabaseWithoutInternals[PublicCompositeTypeNameOrOptions["schema"]]["CompositeTypes"]
    : never) = never,
> = PublicCompositeTypeNameOrOptions extends {
  schema: keyof DatabaseWithoutInternals;
}
  ? DatabaseWithoutInternals[PublicCompositeTypeNameOrOptions["schema"]]["CompositeTypes"][CompositeTypeName]
  : PublicCompositeTypeNameOrOptions extends keyof DefaultSchema["CompositeTypes"]
    ? DefaultSchema["CompositeTypes"][PublicCompositeTypeNameOrOptions]
    : never;

export const Constants = {
  graphql_public: {
    Enums: {},
  },
  public: {
    Enums: {},
  },
} as const;
