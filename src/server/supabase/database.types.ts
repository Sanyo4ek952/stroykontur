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
            referencedRelation: "project_members";
            referencedColumns: ["project_id", "id"];
          },
        ];
      };
      audit_entries: {
        Row: {
          action_key: string;
          actor_project_member_id: string | null;
          actor_user_id: string | null;
          created_at: string;
          id: string;
          occurred_at: string;
          project_id: string;
          subject_id: string;
          subject_type: string;
        };
        Insert: {
          action_key: string;
          actor_project_member_id?: string | null;
          actor_user_id?: string | null;
          created_at?: string;
          id?: string;
          occurred_at?: string;
          project_id: string;
          subject_id: string;
          subject_type: string;
        };
        Update: {
          action_key?: string;
          actor_project_member_id?: string | null;
          actor_user_id?: string | null;
          created_at?: string;
          id?: string;
          occurred_at?: string;
          project_id?: string;
          subject_id?: string;
          subject_type?: string;
        };
        Relationships: [
          {
            foreignKeyName: "audit_entries_actor_project_member_fkey";
            columns: ["project_id", "actor_project_member_id"];
            isOneToOne: false;
            referencedRelation: "project_members";
            referencedColumns: ["project_id", "id"];
          },
          {
            foreignKeyName: "audit_entries_project_id_fkey";
            columns: ["project_id"];
            isOneToOne: false;
            referencedRelation: "projects";
            referencedColumns: ["id"];
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
          created_at: string;
          event_type: string;
          id: string;
          occurred_at: string;
          project_id: string;
          subject_id: string;
          subject_type: string;
        };
        Insert: {
          actor_user_id?: string | null;
          created_at?: string;
          event_type: string;
          id?: string;
          occurred_at?: string;
          project_id: string;
          subject_id: string;
          subject_type: string;
        };
        Update: {
          actor_user_id?: string | null;
          created_at?: string;
          event_type?: string;
          id?: string;
          occurred_at?: string;
          project_id?: string;
          subject_id?: string;
          subject_type?: string;
        };
        Relationships: [
          {
            foreignKeyName: "events_project_id_fkey";
            columns: ["project_id"];
            isOneToOne: false;
            referencedRelation: "projects";
            referencedColumns: ["id"];
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
            referencedRelation: "project_members";
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
            referencedRelation: "project_members";
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
            referencedRelation: "project_members";
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
      work_assignments: {
        Row: {
          assigned_at: string;
          assigned_by: string;
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
            referencedRelation: "project_members";
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
      work_progress_entries: {
        Row: {
          created_at: string;
          created_by: string;
          id: string;
          note: string | null;
          project_id: string;
          quantity: number;
          work_date: string;
          work_id: string;
        };
        Insert: {
          created_at?: string;
          created_by: string;
          id?: string;
          note?: string | null;
          project_id: string;
          quantity: number;
          work_date: string;
          work_id: string;
        };
        Update: {
          created_at?: string;
          created_by?: string;
          id?: string;
          note?: string | null;
          project_id?: string;
          quantity?: number;
          work_date?: string;
          work_id?: string;
        };
        Relationships: [
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
          project_id?: string;
          status?: string;
          title?: string;
          unit?: string | null;
          updated_at?: string;
        };
        Relationships: [
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
      [_ in never]: never;
    };
    Functions: {
      acknowledge_own_document_impact: {
        Args: { notification_id: string };
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
