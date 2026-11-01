export type Json =
  | string
  | number
  | boolean
  | null
  | { [key: string]: Json | undefined }
  | Json[]

export type Database = {
  // Allows to automatically instantiate createClient with right options
  // instead of createClient<Database, { PostgrestVersion: 'XX' }>(URL, KEY)
  __InternalSupabase: {
    PostgrestVersion: "14.5"
  }
  graphql_public: {
    Tables: {
      [_ in never]: never
    }
    Views: {
      [_ in never]: never
    }
    Functions: {
      graphql: {
        Args: {
          extensions?: Json
          operationName?: string
          query?: string
          variables?: Json
        }
        Returns: Json
      }
    }
    Enums: {
      [_ in never]: never
    }
    CompositeTypes: {
      [_ in never]: never
    }
  }
  public: {
    Tables: {
      addresses: {
        Row: {
          city: string
          created_at: string
          district: string | null
          id: string
          is_default: boolean
          label: string | null
          line1: string
          line2: string | null
          phone: string | null
          postal_code: string | null
          profile_id: string
          updated_at: string
        }
        Insert: {
          city: string
          created_at?: string
          district?: string | null
          id?: string
          is_default?: boolean
          label?: string | null
          line1: string
          line2?: string | null
          phone?: string | null
          postal_code?: string | null
          profile_id: string
          updated_at?: string
        }
        Update: {
          city?: string
          created_at?: string
          district?: string | null
          id?: string
          is_default?: boolean
          label?: string | null
          line1?: string
          line2?: string | null
          phone?: string | null
          postal_code?: string | null
          profile_id?: string
          updated_at?: string
        }
        Relationships: [
          {
            foreignKeyName: "addresses_profile_id_fkey"
            columns: ["profile_id"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
        ]
      }
      banners: {
        Row: {
          created_at: string
          cta_href: string | null
          cta_label: string | null
          ends_at: string | null
          id: string
          image_path: string | null
          is_active: boolean
          slot: string
          sort_order: number
          starts_at: string | null
          subtitle: string | null
          title: string | null
          updated_at: string
        }
        Insert: {
          created_at?: string
          cta_href?: string | null
          cta_label?: string | null
          ends_at?: string | null
          id?: string
          image_path?: string | null
          is_active?: boolean
          slot: string
          sort_order?: number
          starts_at?: string | null
          subtitle?: string | null
          title?: string | null
          updated_at?: string
        }
        Update: {
          created_at?: string
          cta_href?: string | null
          cta_label?: string | null
          ends_at?: string | null
          id?: string
          image_path?: string | null
          is_active?: boolean
          slot?: string
          sort_order?: number
          starts_at?: string | null
          subtitle?: string | null
          title?: string | null
          updated_at?: string
        }
        Relationships: []
      }
      cart_items: {
        Row: {
          cart_id: string
          created_at: string
          id: string
          product_id: string
          quantity: number
          updated_at: string
          variant_id: string | null
        }
        Insert: {
          cart_id: string
          created_at?: string
          id?: string
          product_id: string
          quantity?: number
          updated_at?: string
          variant_id?: string | null
        }
        Update: {
          cart_id?: string
          created_at?: string
          id?: string
          product_id?: string
          quantity?: number
          updated_at?: string
          variant_id?: string | null
        }
        Relationships: [
          {
            foreignKeyName: "cart_items_cart_id_fkey"
            columns: ["cart_id"]
            isOneToOne: false
            referencedRelation: "carts"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "cart_items_product_id_fkey"
            columns: ["product_id"]
            isOneToOne: false
            referencedRelation: "products"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "cart_items_variant_id_fkey"
            columns: ["variant_id"]
            isOneToOne: false
            referencedRelation: "product_variants"
            referencedColumns: ["id"]
          },
        ]
      }
      carts: {
        Row: {
          created_at: string
          id: string
          profile_id: string
          updated_at: string
        }
        Insert: {
          created_at?: string
          id?: string
          profile_id: string
          updated_at?: string
        }
        Update: {
          created_at?: string
          id?: string
          profile_id?: string
          updated_at?: string
        }
        Relationships: [
          {
            foreignKeyName: "carts_profile_id_fkey"
            columns: ["profile_id"]
            isOneToOne: true
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
        ]
      }
      categories: {
        Row: {
          allows_shared_barcode: boolean
          default_tracking_mode: string
          created_at: string
          hero_blurb: string | null
          hero_eyebrow: string | null
          hero_headline: string | null
          id: string
          image_path: string | null
          is_active: boolean
          name: string
          parent_id: string | null
          requires_serial: boolean
          slug: string
          sort_order: number
          subtitle: string | null
          updated_at: string
        }
        Insert: {
          allows_shared_barcode?: boolean
          default_tracking_mode?: string
          created_at?: string
          hero_blurb?: string | null
          hero_eyebrow?: string | null
          hero_headline?: string | null
          id?: string
          image_path?: string | null
          is_active?: boolean
          name: string
          parent_id?: string | null
          requires_serial?: boolean
          slug: string
          sort_order?: number
          subtitle?: string | null
          updated_at?: string
        }
        Update: {
          allows_shared_barcode?: boolean
          default_tracking_mode?: string
          created_at?: string
          hero_blurb?: string | null
          hero_eyebrow?: string | null
          hero_headline?: string | null
          id?: string
          image_path?: string | null
          is_active?: boolean
          name?: string
          parent_id?: string | null
          requires_serial?: boolean
          slug?: string
          sort_order?: number
          subtitle?: string | null
          updated_at?: string
        }
        Relationships: [
          {
            foreignKeyName: "categories_parent_id_fkey"
            columns: ["parent_id"]
            isOneToOne: false
            referencedRelation: "categories"
            referencedColumns: ["id"]
          },
        ]
      }
      condition_grades: {
        Row: {
          code: string
          created_at: string
          description: string | null
          id: string
          is_active: boolean
          label: string
          sort_order: number
          updated_at: string
        }
        Insert: {
          code: string
          created_at?: string
          description?: string | null
          id?: string
          is_active?: boolean
          label: string
          sort_order?: number
          updated_at?: string
        }
        Update: {
          code?: string
          created_at?: string
          description?: string | null
          id?: string
          is_active?: boolean
          label?: string
          sort_order?: number
          updated_at?: string
        }
        Relationships: []
      }
      device_models: {
        Row: {
          created_at: string
          id: string
          image_path: string | null
          is_active: boolean
          name: string
          series: string | null
          sort_order: number
          updated_at: string
        }
        Insert: {
          created_at?: string
          id: string
          image_path?: string | null
          is_active?: boolean
          name: string
          series?: string | null
          sort_order?: number
          updated_at?: string
        }
        Update: {
          created_at?: string
          id?: string
          image_path?: string | null
          is_active?: boolean
          name?: string
          series?: string | null
          sort_order?: number
          updated_at?: string
        }
        Relationships: []
      }
      featured_products: {
        Row: {
          created_at: string
          id: string
          is_active: boolean
          position: number
          product_id: string
          slot: string
          updated_at: string
        }
        Insert: {
          created_at?: string
          id?: string
          is_active?: boolean
          position?: number
          product_id: string
          slot?: string
          updated_at?: string
        }
        Update: {
          created_at?: string
          id?: string
          is_active?: boolean
          position?: number
          product_id?: string
          slot?: string
          updated_at?: string
        }
        Relationships: [
          {
            foreignKeyName: "featured_products_product_id_fkey"
            columns: ["product_id"]
            isOneToOne: false
            referencedRelation: "products"
            referencedColumns: ["id"]
          },
        ]
      }
      grn_lines: {
        Row: {
          ordered_quantity: number | null
          received_quantity: number
          rejected_quantity: number
          rejection_reason: string | null
          purchase_order_line_id: string | null
          po_unit_cost_cents: number | null
          cost_pending: boolean
          cost_note: string | null
          corrected_quantity: number
          returned_quantity: number
          tracking_mode_snapshot: string
          grn_id: string
          id: string
          line_no: number
          product_id: string
          product_name_snapshot: string
          accepted_quantity: number
          unit_cost_cents: number | null
          variant_id: string | null
          variant_label_snapshot: string | null
        }
        Insert: {
          ordered_quantity?: number | null
          received_quantity?: number
          rejected_quantity?: number
          rejection_reason?: string | null
          purchase_order_line_id?: string | null
          po_unit_cost_cents?: number | null
          cost_pending?: boolean
          cost_note?: string | null
          corrected_quantity?: number
          returned_quantity?: number
          tracking_mode_snapshot?: string
          grn_id: string
          id?: string
          line_no: number
          product_id: string
          product_name_snapshot: string
          accepted_quantity: number
          unit_cost_cents?: number | null
          variant_id?: string | null
          variant_label_snapshot?: string | null
        }
        Update: {
          ordered_quantity?: number | null
          received_quantity?: number
          rejected_quantity?: number
          rejection_reason?: string | null
          purchase_order_line_id?: string | null
          po_unit_cost_cents?: number | null
          cost_pending?: boolean
          cost_note?: string | null
          corrected_quantity?: number
          returned_quantity?: number
          tracking_mode_snapshot?: string
          grn_id?: string
          id?: string
          line_no?: number
          product_id?: string
          product_name_snapshot?: string
          accepted_quantity?: number
          unit_cost_cents?: number | null
          variant_id?: string | null
          variant_label_snapshot?: string | null
        }
        Relationships: [
          {
            foreignKeyName: "grn_lines_grn_id_fkey"
            columns: ["grn_id"]
            isOneToOne: false
            referencedRelation: "grns"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "grn_lines_product_id_fkey"
            columns: ["product_id"]
            isOneToOne: false
            referencedRelation: "products"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "grn_lines_variant_fk"
            columns: ["variant_id", "product_id"]
            isOneToOne: false
            referencedRelation: "product_variants"
            referencedColumns: ["id", "product_id"]
          },
        ]
      }
      grns: {
        Row: {
          source_type: string
          request_fingerprint: string | null
          rejected_units: number
          corrected_cost_cents: number
          pending_cost_lines: number
          duplicate_invoice_note: string | null
          created_at: string
          created_by: string | null
          grn_number: string
          id: string
          note: string | null
          purchase_order_id: string | null
          received_on: string
          request_id: string
          supplier_id: string | null
          supplier_invoice: string | null
          supplier_name: string
          total_cost_cents: number
          total_units: number
        }
        Insert: {
          source_type?: string
          request_fingerprint?: string | null
          rejected_units?: number
          corrected_cost_cents?: number
          pending_cost_lines?: number
          duplicate_invoice_note?: string | null
          created_at?: string
          created_by?: string | null
          grn_number: string
          id?: string
          note?: string | null
          purchase_order_id?: string | null
          received_on: string
          request_id: string
          supplier_id?: string | null
          supplier_invoice?: string | null
          supplier_name: string
          total_cost_cents?: number
          total_units: number
        }
        Update: {
          source_type?: string
          request_fingerprint?: string | null
          rejected_units?: number
          corrected_cost_cents?: number
          pending_cost_lines?: number
          duplicate_invoice_note?: string | null
          created_at?: string
          created_by?: string | null
          grn_number?: string
          id?: string
          note?: string | null
          purchase_order_id?: string | null
          received_on?: string
          request_id?: string
          supplier_id?: string | null
          supplier_invoice?: string | null
          supplier_name?: string
          total_cost_cents?: number
          total_units?: number
        }
        Relationships: [
          {
            foreignKeyName: "grns_created_by_fkey"
            columns: ["created_by"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "grns_purchase_order_id_fkey"
            columns: ["purchase_order_id"]
            isOneToOne: false
            referencedRelation: "purchase_orders"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "grns_supplier_id_fkey"
            columns: ["supplier_id"]
            isOneToOne: false
            referencedRelation: "suppliers"
            referencedColumns: ["id"]
          },
        ]
      }
      inventory_movements: {
        Row: {
          order_item_id: string | null
          actor_id: string | null
          created_at: string
          delta: number
          entry_seq: number
          grn_id: string | null
          id: string
          note: string | null
          order_id: string | null
          pos_sale_id: string | null
          product_id: string
          quantity_after: number | null
          quantity_before: number | null
          reason: string
          request_id: string | null
          txid: unknown
          variant_id: string | null
        }
        Insert: {
          order_item_id?: string | null
          actor_id?: string | null
          created_at?: string
          delta: number
          entry_seq?: never
          grn_id?: string | null
          id?: string
          note?: string | null
          order_id?: string | null
          pos_sale_id?: string | null
          product_id: string
          quantity_after?: number | null
          quantity_before?: number | null
          reason: string
          request_id?: string | null
          txid?: unknown
          variant_id?: string | null
        }
        Update: {
          order_item_id?: string | null
          actor_id?: string | null
          created_at?: string
          delta?: number
          entry_seq?: never
          grn_id?: string | null
          id?: string
          note?: string | null
          order_id?: string | null
          pos_sale_id?: string | null
          product_id?: string
          quantity_after?: number | null
          quantity_before?: number | null
          reason?: string
          request_id?: string | null
          txid?: unknown
          variant_id?: string | null
        }
        Relationships: [
          {
            foreignKeyName: "inventory_movements_actor_id_fkey"
            columns: ["actor_id"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "inventory_movements_grn_id_fkey"
            columns: ["grn_id"]
            isOneToOne: false
            referencedRelation: "grns"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "inventory_movements_order_id_fkey"
            columns: ["order_id"]
            isOneToOne: false
            referencedRelation: "orders"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "inventory_movements_pos_sale_id_fkey"
            columns: ["pos_sale_id"]
            isOneToOne: false
            referencedRelation: "pos_sales"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "inventory_movements_product_id_fkey"
            columns: ["product_id"]
            isOneToOne: false
            referencedRelation: "products"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "inventory_movements_variant_id_fkey"
            columns: ["variant_id"]
            isOneToOne: false
            referencedRelation: "product_variants"
            referencedColumns: ["id"]
          },
        ]
      }
      inventory_units: {
        Row: {
          location_code: string
          reentry_of_unit_id: string | null
          barcode: string
          created_at: string
          fifo_seq: number
          grn_id: string
          grn_line_id: string
          id: string
          order_id: string | null
          order_item_id: string | null
          pos_sale_id: string | null
          product_id: string
          received_on: string
          serial_number: string | null
          status: string
          status_changed_at: string
          status_note: string | null
          supplier_return_id: string | null
          unit_cost_cents: number | null
          variant_id: string | null
        }
        Insert: {
          location_code?: string
          reentry_of_unit_id?: string | null
          barcode: string
          created_at?: string
          fifo_seq?: never
          grn_id: string
          grn_line_id: string
          id?: string
          order_id?: string | null
          order_item_id?: string | null
          pos_sale_id?: string | null
          product_id: string
          received_on: string
          serial_number?: string | null
          status?: string
          status_changed_at?: string
          status_note?: string | null
          supplier_return_id?: string | null
          unit_cost_cents?: number | null
          variant_id?: string | null
        }
        Update: {
          location_code?: string
          reentry_of_unit_id?: string | null
          barcode?: string
          created_at?: string
          fifo_seq?: never
          grn_id?: string
          grn_line_id?: string
          id?: string
          order_id?: string | null
          order_item_id?: string | null
          pos_sale_id?: string | null
          product_id?: string
          received_on?: string
          serial_number?: string | null
          status?: string
          status_changed_at?: string
          status_note?: string | null
          supplier_return_id?: string | null
          unit_cost_cents?: number | null
          variant_id?: string | null
        }
        Relationships: [
          {
            foreignKeyName: "inventory_units_grn_id_fkey"
            columns: ["grn_id"]
            isOneToOne: false
            referencedRelation: "grns"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "inventory_units_grn_line_id_fkey"
            columns: ["grn_line_id"]
            isOneToOne: false
            referencedRelation: "grn_lines"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "inventory_units_order_id_fkey"
            columns: ["order_id"]
            isOneToOne: false
            referencedRelation: "orders"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "inventory_units_order_item_id_fkey"
            columns: ["order_item_id"]
            isOneToOne: false
            referencedRelation: "order_items"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "inventory_units_pos_sale_id_fkey"
            columns: ["pos_sale_id"]
            isOneToOne: false
            referencedRelation: "pos_sales"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "inventory_units_product_id_fkey"
            columns: ["product_id"]
            isOneToOne: false
            referencedRelation: "products"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "inventory_units_variant_fk"
            columns: ["variant_id", "product_id"]
            isOneToOne: false
            referencedRelation: "product_variants"
            referencedColumns: ["id", "product_id"]
          },
          {
            foreignKeyName: "inventory_units_supplier_return_id_fkey"
            columns: ["supplier_return_id"]
            isOneToOne: false
            referencedRelation: "supplier_returns"
            referencedColumns: ["id"]
          },
        ]
      }
      order_events: {
        Row: {
          actor_id: string | null
          created_at: string
          from_status: string | null
          id: string
          note: string | null
          order_id: string
          to_status: string
        }
        Insert: {
          actor_id?: string | null
          created_at?: string
          from_status?: string | null
          id?: string
          note?: string | null
          order_id: string
          to_status: string
        }
        Update: {
          actor_id?: string | null
          created_at?: string
          from_status?: string | null
          id?: string
          note?: string | null
          order_id?: string
          to_status?: string
        }
        Relationships: [
          {
            foreignKeyName: "order_events_actor_id_fkey"
            columns: ["actor_id"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "order_events_order_id_fkey"
            columns: ["order_id"]
            isOneToOne: false
            referencedRelation: "orders"
            referencedColumns: ["id"]
          },
        ]
      }
      order_items: {
        Row: {
          stock_consumed_at: string | null
          returned_quantity: number
          base_unit_price_cents: number | null
          condition_grade_snapshot: string | null
          condition_snapshot: string | null
          created_at: string
          id: string
          image_path_snapshot: string | null
          line_total_cents: number
          order_id: string
          price_id: string | null
          product_id: string | null
          product_name_snapshot: string
          quantity: number
          tier_code_snapshot: string
          unit_price_cents: number
          variant_id: string | null
          variant_label_snapshot: string | null
          warranty_label_snapshot: string | null
          warranty_months_snapshot: number | null
          warranty_option_id: string | null
          warranty_price_cents_snapshot: number
        }
        Insert: {
          stock_consumed_at?: string | null
          returned_quantity?: number
          base_unit_price_cents?: number | null
          condition_grade_snapshot?: string | null
          condition_snapshot?: string | null
          created_at?: string
          id?: string
          image_path_snapshot?: string | null
          line_total_cents: number
          order_id: string
          price_id?: string | null
          product_id?: string | null
          product_name_snapshot: string
          quantity: number
          tier_code_snapshot: string
          unit_price_cents: number
          variant_id?: string | null
          variant_label_snapshot?: string | null
          warranty_label_snapshot?: string | null
          warranty_months_snapshot?: number | null
          warranty_option_id?: string | null
          warranty_price_cents_snapshot?: number
        }
        Update: {
          stock_consumed_at?: string | null
          returned_quantity?: number
          base_unit_price_cents?: number | null
          condition_grade_snapshot?: string | null
          condition_snapshot?: string | null
          created_at?: string
          id?: string
          image_path_snapshot?: string | null
          line_total_cents?: number
          order_id?: string
          price_id?: string | null
          product_id?: string | null
          product_name_snapshot?: string
          quantity?: number
          tier_code_snapshot?: string
          unit_price_cents?: number
          variant_id?: string | null
          variant_label_snapshot?: string | null
          warranty_label_snapshot?: string | null
          warranty_months_snapshot?: number | null
          warranty_option_id?: string | null
          warranty_price_cents_snapshot?: number
        }
        Relationships: [
          {
            foreignKeyName: "order_items_order_id_fkey"
            columns: ["order_id"]
            isOneToOne: false
            referencedRelation: "orders"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "order_items_price_id_fkey"
            columns: ["price_id"]
            isOneToOne: false
            referencedRelation: "my_prices"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "order_items_price_id_fkey"
            columns: ["price_id"]
            isOneToOne: false
            referencedRelation: "product_prices"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "order_items_product_id_fkey"
            columns: ["product_id"]
            isOneToOne: false
            referencedRelation: "products"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "order_items_variant_id_fkey"
            columns: ["variant_id"]
            isOneToOne: false
            referencedRelation: "product_variants"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "order_items_warranty_option_id_fkey"
            columns: ["warranty_option_id"]
            isOneToOne: false
            referencedRelation: "product_warranty_options"
            referencedColumns: ["id"]
          },
        ]
      }
      orders: {
        Row: {
          reservation_expires_at: string | null
          request_id: string | null
          request_fingerprint: string | null
          created_at: string
          currency: string
          customer_type_at_purchase: string
          delivery_cents: number
          discount_cents: number
          id: string
          notes: string | null
          order_number: string
          placed_at: string
          profile_id: string
          shipping_address: Json | null
          status: string
          stock_state: string
          subtotal_cents: number
          total_cents: number
          updated_at: string
        }
        Insert: {
          reservation_expires_at?: string | null
          request_id?: string | null
          request_fingerprint?: string | null
          created_at?: string
          currency?: string
          customer_type_at_purchase: string
          delivery_cents?: number
          discount_cents?: number
          id?: string
          notes?: string | null
          order_number: string
          placed_at?: string
          profile_id: string
          shipping_address?: Json | null
          status?: string
          stock_state?: string | null
          subtotal_cents?: number
          total_cents?: number
          updated_at?: string
        }
        Update: {
          reservation_expires_at?: string | null
          request_id?: string | null
          request_fingerprint?: string | null
          created_at?: string
          currency?: string
          customer_type_at_purchase?: string
          delivery_cents?: number
          discount_cents?: number
          id?: string
          notes?: string | null
          order_number?: string
          placed_at?: string
          profile_id?: string
          shipping_address?: Json | null
          status?: string
          stock_state?: string | null
          subtotal_cents?: number
          total_cents?: number
          updated_at?: string
        }
        Relationships: [
          {
            foreignKeyName: "orders_customer_type_at_purchase_fkey"
            columns: ["customer_type_at_purchase"]
            isOneToOne: false
            referencedRelation: "price_tiers"
            referencedColumns: ["code"]
          },
          {
            foreignKeyName: "orders_profile_id_fkey"
            columns: ["profile_id"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
        ]
      }
      payments: {
        Row: {
          amount_cents: number
          created_at: string
          id: string
          order_id: string
          provider: string
          provider_ref: string | null
          raw: Json | null
          status: string
          updated_at: string
        }
        Insert: {
          amount_cents: number
          created_at?: string
          id?: string
          order_id: string
          provider: string
          provider_ref?: string | null
          raw?: Json | null
          status?: string
          updated_at?: string
        }
        Update: {
          amount_cents?: number
          created_at?: string
          id?: string
          order_id?: string
          provider?: string
          provider_ref?: string | null
          raw?: Json | null
          status?: string
          updated_at?: string
        }
        Relationships: [
          {
            foreignKeyName: "payments_order_id_fkey"
            columns: ["order_id"]
            isOneToOne: false
            referencedRelation: "orders"
            referencedColumns: ["id"]
          },
        ]
      }
      pos_sale_items: {
        Row: {
          quantity: number
          line_total_cents: number
          tier_code_snapshot: string
          returned_quantity: number
          barcode_snapshot: string | null
          id: string
          pos_sale_id: string
          price_id: string | null
          product_id: string | null
          product_name_snapshot: string
          return_note: string | null
          returned_at: string | null
          serial_snapshot: string | null
          unit_id: string | null
          unit_price_cents: number
          variant_id: string | null
          variant_label_snapshot: string | null
        }
        Insert: {
          quantity?: number
          line_total_cents?: number
          tier_code_snapshot?: string
          returned_quantity?: number
          barcode_snapshot: string | null
          id?: string
          pos_sale_id: string
          price_id?: string | null
          product_id?: string | null
          product_name_snapshot: string
          return_note?: string | null
          returned_at?: string | null
          serial_snapshot?: string | null
          unit_id: string | null
          unit_price_cents: number
          variant_id?: string | null
          variant_label_snapshot?: string | null
        }
        Update: {
          quantity?: number
          line_total_cents?: number
          tier_code_snapshot?: string
          returned_quantity?: number
          barcode_snapshot?: string | null
          id?: string
          pos_sale_id?: string
          price_id?: string | null
          product_id?: string | null
          product_name_snapshot?: string
          return_note?: string | null
          returned_at?: string | null
          serial_snapshot?: string | null
          unit_id?: string | null
          unit_price_cents?: number
          variant_id?: string | null
          variant_label_snapshot?: string | null
        }
        Relationships: [
          {
            foreignKeyName: "pos_sale_items_pos_sale_id_fkey"
            columns: ["pos_sale_id"]
            isOneToOne: false
            referencedRelation: "pos_sales"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "pos_sale_items_price_id_fkey"
            columns: ["price_id"]
            isOneToOne: false
            referencedRelation: "my_prices"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "pos_sale_items_price_id_fkey"
            columns: ["price_id"]
            isOneToOne: false
            referencedRelation: "product_prices"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "pos_sale_items_product_id_fkey"
            columns: ["product_id"]
            isOneToOne: false
            referencedRelation: "products"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "pos_sale_items_unit_id_fkey"
            columns: ["unit_id"]
            isOneToOne: false
            referencedRelation: "inventory_units"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "pos_sale_items_variant_id_fkey"
            columns: ["variant_id"]
            isOneToOne: false
            referencedRelation: "product_variants"
            referencedColumns: ["id"]
          },
        ]
      }
      pos_sales: {
        Row: {
          customer_profile_id: string | null
          tier_code: string
          payment_reference: string | null
          request_fingerprint: string | null
          discount_approval_id: string | null
          bill_number: string
          cashier_id: string | null
          created_at: string
          customer_name: string | null
          customer_phone: string | null
          discount_cents: number
          id: string
          note: string | null
          payment_method: string
          request_id: string
          subtotal_cents: number
          total_cents: number
        }
        Insert: {
          customer_profile_id?: string | null
          tier_code?: string
          payment_reference?: string | null
          request_fingerprint?: string | null
          discount_approval_id?: string | null
          bill_number: string
          cashier_id?: string | null
          created_at?: string
          customer_name?: string | null
          customer_phone?: string | null
          discount_cents?: number
          id?: string
          note?: string | null
          payment_method: string
          request_id: string
          subtotal_cents: number
          total_cents: number
        }
        Update: {
          customer_profile_id?: string | null
          tier_code?: string
          payment_reference?: string | null
          request_fingerprint?: string | null
          discount_approval_id?: string | null
          bill_number?: string
          cashier_id?: string | null
          created_at?: string
          customer_name?: string | null
          customer_phone?: string | null
          discount_cents?: number
          id?: string
          note?: string | null
          payment_method?: string
          request_id?: string
          subtotal_cents?: number
          total_cents?: number
        }
        Relationships: [
          {
            foreignKeyName: "pos_sales_cashier_id_fkey"
            columns: ["cashier_id"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
        ]
      }
      price_tiers: {
        Row: {
          code: string
          created_at: string
          is_public: boolean
          name: string
          sort_order: number
          updated_at: string
        }
        Insert: {
          code: string
          created_at?: string
          is_public?: boolean
          name: string
          sort_order?: number
          updated_at?: string
        }
        Update: {
          code?: string
          created_at?: string
          is_public?: boolean
          name?: string
          sort_order?: number
          updated_at?: string
        }
        Relationships: []
      }
      product_compatibility: {
        Row: {
          device_model_id: string | null
          id: string
          label: string
          part_kind: string | null
          position: number
          product_id: string
        }
        Insert: {
          device_model_id?: string | null
          id?: string
          label: string
          part_kind?: string | null
          position?: number
          product_id: string
        }
        Update: {
          device_model_id?: string | null
          id?: string
          label?: string
          part_kind?: string | null
          position?: number
          product_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "product_compatibility_device_model_id_fkey"
            columns: ["device_model_id"]
            isOneToOne: false
            referencedRelation: "device_models"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "product_compatibility_product_id_fkey"
            columns: ["product_id"]
            isOneToOne: false
            referencedRelation: "products"
            referencedColumns: ["id"]
          },
        ]
      }
      product_conditions: {
        Row: {
          accessories_included: string | null
          battery_health: number | null
          condition: string
          condition_grade_id: string | null
          created_at: string
          cycle_count: number | null
          device_notes: string | null
          id: string
          physical_condition: string | null
          product_id: string
          updated_at: string
          variant_id: string | null
        }
        Insert: {
          accessories_included?: string | null
          battery_health?: number | null
          condition: string
          condition_grade_id?: string | null
          created_at?: string
          cycle_count?: number | null
          device_notes?: string | null
          id?: string
          physical_condition?: string | null
          product_id: string
          updated_at?: string
          variant_id?: string | null
        }
        Update: {
          accessories_included?: string | null
          battery_health?: number | null
          condition?: string
          condition_grade_id?: string | null
          created_at?: string
          cycle_count?: number | null
          device_notes?: string | null
          id?: string
          physical_condition?: string | null
          product_id?: string
          updated_at?: string
          variant_id?: string | null
        }
        Relationships: [
          {
            foreignKeyName: "product_conditions_condition_grade_id_fkey"
            columns: ["condition_grade_id"]
            isOneToOne: false
            referencedRelation: "condition_grades"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "product_conditions_product_id_fkey"
            columns: ["product_id"]
            isOneToOne: false
            referencedRelation: "products"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "product_conditions_variant_fk"
            columns: ["variant_id", "product_id"]
            isOneToOne: false
            referencedRelation: "product_variants"
            referencedColumns: ["id", "product_id"]
          },
        ]
      }
      product_images: {
        Row: {
          alt: string | null
          created_at: string
          id: string
          is_primary: boolean
          path: string
          position: number
          product_id: string
          storage_bucket: string | null
          variant_id: string | null
        }
        Insert: {
          alt?: string | null
          created_at?: string
          id?: string
          is_primary?: boolean
          path: string
          position?: number
          product_id: string
          storage_bucket?: string | null
          variant_id?: string | null
        }
        Update: {
          alt?: string | null
          created_at?: string
          id?: string
          is_primary?: boolean
          path?: string
          position?: number
          product_id?: string
          storage_bucket?: string | null
          variant_id?: string | null
        }
        Relationships: [
          {
            foreignKeyName: "product_images_product_id_fkey"
            columns: ["product_id"]
            isOneToOne: false
            referencedRelation: "products"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "product_images_variant_fk"
            columns: ["variant_id", "product_id"]
            isOneToOne: false
            referencedRelation: "product_variants"
            referencedColumns: ["id", "product_id"]
          },
        ]
      }
      barcode_registry: {
        Row: {
          created_at: string
          kind: string
          product_barcode_id: string | null
          unit_id: string | null
          value: string
        }
        Insert: {
          created_at?: string
          kind: string
          product_barcode_id?: string | null
          unit_id?: string | null
          value: string
        }
        Update: {
          created_at?: string
          kind?: string
          product_barcode_id?: string | null
          unit_id?: string | null
          value?: string
        }
        Relationships: []
      }
      product_barcodes: {
        Row: {
          created_at: string
          created_by: string | null
          id: string
          product_id: string
          retire_note: string | null
          retired_at: string | null
          retired_by: string | null
          source: string
          status: string
          value: string
          variant_id: string | null
        }
        Insert: {
          created_at?: string
          created_by?: string | null
          id?: string
          product_id: string
          retire_note?: string | null
          retired_at?: string | null
          retired_by?: string | null
          source: string
          status?: string
          value: string
          variant_id?: string | null
        }
        Update: {
          created_at?: string
          created_by?: string | null
          id?: string
          product_id?: string
          retire_note?: string | null
          retired_at?: string | null
          retired_by?: string | null
          source?: string
          status?: string
          value?: string
          variant_id?: string | null
        }
        Relationships: []
      }
      product_prices: {
        Row: {
          created_at: string
          created_by: string | null
          ends_at: string | null
          id: string
          min_qty: number
          price_cents: number
          product_id: string
          starts_at: string
          tier_code: string
          updated_at: string
          variant_id: string | null
        }
        Insert: {
          created_at?: string
          created_by?: string | null
          ends_at?: string | null
          id?: string
          min_qty?: number
          price_cents: number
          product_id: string
          starts_at?: string
          tier_code: string
          updated_at?: string
          variant_id?: string | null
        }
        Update: {
          created_at?: string
          created_by?: string | null
          ends_at?: string | null
          id?: string
          min_qty?: number
          price_cents?: number
          product_id?: string
          starts_at?: string
          tier_code?: string
          updated_at?: string
          variant_id?: string | null
        }
        Relationships: [
          {
            foreignKeyName: "product_prices_created_by_fkey"
            columns: ["created_by"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "product_prices_product_id_fkey"
            columns: ["product_id"]
            isOneToOne: false
            referencedRelation: "products"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "product_prices_tier_code_fkey"
            columns: ["tier_code"]
            isOneToOne: false
            referencedRelation: "price_tiers"
            referencedColumns: ["code"]
          },
          {
            foreignKeyName: "product_prices_variant_id_fkey"
            columns: ["variant_id"]
            isOneToOne: false
            referencedRelation: "product_variants"
            referencedColumns: ["id"]
          },
        ]
      }
      product_specs: {
        Row: {
          id: string
          label: string
          position: number
          product_id: string
          value: string
        }
        Insert: {
          id?: string
          label: string
          position?: number
          product_id: string
          value: string
        }
        Update: {
          id?: string
          label?: string
          position?: number
          product_id?: string
          value?: string
        }
        Relationships: [
          {
            foreignKeyName: "product_specs_product_id_fkey"
            columns: ["product_id"]
            isOneToOne: false
            referencedRelation: "products"
            referencedColumns: ["id"]
          },
        ]
      }
      product_variants: {
        Row: {
          tracking_mode: string | null
          color: string | null
          color_code: string | null
          created_at: string
          id: string
          legacy_key: string | null
          name: string
          product_id: string
          sort_order: number
          stock: number | null
          storage: string | null
          updated_at: string
        }
        Insert: {
          tracking_mode?: string | null
          color?: string | null
          color_code?: string | null
          created_at?: string
          id?: string
          legacy_key?: string | null
          name: string
          product_id: string
          sort_order?: number
          stock?: number | null
          storage?: string | null
          updated_at?: string
        }
        Update: {
          tracking_mode?: string | null
          color?: string | null
          color_code?: string | null
          created_at?: string
          id?: string
          legacy_key?: string | null
          name?: string
          product_id?: string
          sort_order?: number
          stock?: number | null
          storage?: string | null
          updated_at?: string
        }
        Relationships: [
          {
            foreignKeyName: "product_variants_product_id_fkey"
            columns: ["product_id"]
            isOneToOne: false
            referencedRelation: "products"
            referencedColumns: ["id"]
          },
        ]
      }
      product_warranty_options: {
        Row: {
          additional_price_cents: number
          created_at: string
          display_order: number
          duration_months: number
          id: string
          is_default: boolean
          is_enabled: boolean
          plan_id: string
          product_id: string
          updated_at: string
        }
        Insert: {
          additional_price_cents?: number
          created_at?: string
          display_order?: number
          duration_months: number
          id?: string
          is_default?: boolean
          is_enabled?: boolean
          plan_id: string
          product_id: string
          updated_at?: string
        }
        Update: {
          additional_price_cents?: number
          created_at?: string
          display_order?: number
          duration_months?: number
          id?: string
          is_default?: boolean
          is_enabled?: boolean
          plan_id?: string
          product_id?: string
          updated_at?: string
        }
        Relationships: [
          {
            foreignKeyName: "product_warranty_options_plan_fk"
            columns: ["plan_id", "product_id"]
            isOneToOne: false
            referencedRelation: "product_warranty_plans"
            referencedColumns: ["id", "product_id"]
          },
          {
            foreignKeyName: "product_warranty_options_product_id_fkey"
            columns: ["product_id"]
            isOneToOne: false
            referencedRelation: "products"
            referencedColumns: ["id"]
          },
        ]
      }
      product_warranty_plans: {
        Row: {
          created_at: string
          id: string
          product_id: string
          updated_at: string
          variant_id: string | null
          warranty_covered: string[]
          warranty_description: string | null
          warranty_duration: string | null
          warranty_excluded: string[]
          warranty_months: number | null
          warranty_title: string | null
          warranty_type: string
        }
        Insert: {
          created_at?: string
          id?: string
          product_id: string
          updated_at?: string
          variant_id?: string | null
          warranty_covered?: string[]
          warranty_description?: string | null
          warranty_duration?: string | null
          warranty_excluded?: string[]
          warranty_months?: number | null
          warranty_title?: string | null
          warranty_type?: string
        }
        Update: {
          created_at?: string
          id?: string
          product_id?: string
          updated_at?: string
          variant_id?: string | null
          warranty_covered?: string[]
          warranty_description?: string | null
          warranty_duration?: string | null
          warranty_excluded?: string[]
          warranty_months?: number | null
          warranty_title?: string | null
          warranty_type?: string
        }
        Relationships: [
          {
            foreignKeyName: "product_warranty_plans_product_id_fkey"
            columns: ["product_id"]
            isOneToOne: false
            referencedRelation: "products"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "product_warranty_plans_variant_fk"
            columns: ["variant_id", "product_id"]
            isOneToOne: false
            referencedRelation: "product_variants"
            referencedColumns: ["id", "product_id"]
          },
        ]
      }
      products: {
        Row: {
          tracking_mode: string
          accessories_included: string | null
          battery_health: number | null
          category_id: string
          condition: string
          condition_grade_id: string | null
          created_at: string
          cycle_count: number | null
          description: string
          device_notes: string | null
          id: string
          is_active: boolean
          is_new: boolean
          lifecycle_status: string | null
          model: string | null
          name: string
          physical_condition: string | null
          rating: number | null
          reviews_count: number
          sort_order: number
          stock: number
          subcategory: string
          updated_at: string
          warranty_coverage: string | null
          warranty_covered: string[]
          warranty_description: string | null
          warranty_duration: string | null
          warranty_excluded: string[]
          warranty_months: number | null
          warranty_status: string | null
          warranty_text: string | null
          warranty_title: string | null
          warranty_type: string
        }
        Insert: {
          tracking_mode?: string
          accessories_included?: string | null
          battery_health?: number | null
          category_id: string
          condition?: string
          condition_grade_id?: string | null
          created_at?: string
          cycle_count?: number | null
          description?: string
          device_notes?: string | null
          id: string
          is_active?: boolean
          is_new?: boolean
          lifecycle_status?: string | null
          model?: string | null
          name: string
          physical_condition?: string | null
          rating?: number | null
          reviews_count?: number
          sort_order?: number
          stock?: number
          subcategory: string
          updated_at?: string
          warranty_coverage?: string | null
          warranty_covered?: string[]
          warranty_description?: string | null
          warranty_duration?: string | null
          warranty_excluded?: string[]
          warranty_months?: number | null
          warranty_status?: string | null
          warranty_text?: string | null
          warranty_title?: string | null
          warranty_type?: string
        }
        Update: {
          tracking_mode?: string
          accessories_included?: string | null
          battery_health?: number | null
          category_id?: string
          condition?: string
          condition_grade_id?: string | null
          created_at?: string
          cycle_count?: number | null
          description?: string
          device_notes?: string | null
          id?: string
          is_active?: boolean
          is_new?: boolean
          lifecycle_status?: string | null
          model?: string | null
          name?: string
          physical_condition?: string | null
          rating?: number | null
          reviews_count?: number
          sort_order?: number
          stock?: number
          subcategory?: string
          updated_at?: string
          warranty_coverage?: string | null
          warranty_covered?: string[]
          warranty_description?: string | null
          warranty_duration?: string | null
          warranty_excluded?: string[]
          warranty_months?: number | null
          warranty_status?: string | null
          warranty_text?: string | null
          warranty_title?: string | null
          warranty_type?: string
        }
        Relationships: [
          {
            foreignKeyName: "products_category_id_fkey"
            columns: ["category_id"]
            isOneToOne: false
            referencedRelation: "categories"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "products_condition_grade_id_fkey"
            columns: ["condition_grade_id"]
            isOneToOne: false
            referencedRelation: "condition_grades"
            referencedColumns: ["id"]
          },
        ]
      }
      profiles: {
        Row: {
          avatar_url: string | null
          created_at: string
          customer_type: string
          email: string | null
          full_name: string | null
          id: string
          phone: string | null
          updated_at: string
          vip_approved_at: string | null
          vip_approved_by: string | null
          vip_expires_at: string | null
        }
        Insert: {
          avatar_url?: string | null
          created_at?: string
          customer_type?: string
          email?: string | null
          full_name?: string | null
          id: string
          phone?: string | null
          updated_at?: string
          vip_approved_at?: string | null
          vip_approved_by?: string | null
          vip_expires_at?: string | null
        }
        Update: {
          avatar_url?: string | null
          created_at?: string
          customer_type?: string
          email?: string | null
          full_name?: string | null
          id?: string
          phone?: string | null
          updated_at?: string
          vip_approved_at?: string | null
          vip_approved_by?: string | null
          vip_expires_at?: string | null
        }
        Relationships: [
          {
            foreignKeyName: "profiles_customer_type_fkey"
            columns: ["customer_type"]
            isOneToOne: false
            referencedRelation: "price_tiers"
            referencedColumns: ["code"]
          },
          {
            foreignKeyName: "profiles_vip_approved_by_fkey"
            columns: ["vip_approved_by"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
        ]
      }
      purchase_order_lines: {
        Row: {
          rejected_quantity: number
          returned_quantity: number
          cost_pending: boolean
          id: string
          line_no: number
          product_id: string
          product_name_snapshot: string
          purchase_order_id: string
          quantity: number
          received_quantity: number
          unit_cost_cents: number | null
          variant_id: string | null
          variant_label_snapshot: string | null
        }
        Insert: {
          rejected_quantity?: number
          returned_quantity?: number
          cost_pending?: boolean
          id?: string
          line_no: number
          product_id: string
          product_name_snapshot: string
          purchase_order_id: string
          quantity: number
          received_quantity?: number
          unit_cost_cents?: number | null
          variant_id?: string | null
          variant_label_snapshot?: string | null
        }
        Update: {
          rejected_quantity?: number
          returned_quantity?: number
          cost_pending?: boolean
          id?: string
          line_no?: number
          product_id?: string
          product_name_snapshot?: string
          purchase_order_id?: string
          quantity?: number
          received_quantity?: number
          unit_cost_cents?: number | null
          variant_id?: string | null
          variant_label_snapshot?: string | null
        }
        Relationships: [
          {
            foreignKeyName: "purchase_order_lines_product_id_fkey"
            columns: ["product_id"]
            isOneToOne: false
            referencedRelation: "products"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "purchase_order_lines_purchase_order_id_fkey"
            columns: ["purchase_order_id"]
            isOneToOne: false
            referencedRelation: "purchase_orders"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "purchase_order_lines_variant_fk"
            columns: ["variant_id", "product_id"]
            isOneToOne: false
            referencedRelation: "product_variants"
            referencedColumns: ["id", "product_id"]
          },
        ]
      }
      purchase_orders: {
        Row: {
          request_fingerprint: string | null
          close_note: string | null
          closed_at: string | null
          created_at: string
          created_by: string | null
          expected_date: string | null
          id: string
          note: string | null
          order_date: string
          po_number: string
          request_id: string
          status: string
          supplier_id: string
          total_cents: number
        }
        Insert: {
          request_fingerprint?: string | null
          close_note?: string | null
          closed_at?: string | null
          created_at?: string
          created_by?: string | null
          expected_date?: string | null
          id?: string
          note?: string | null
          order_date: string
          po_number: string
          request_id: string
          status?: string
          supplier_id: string
          total_cents?: number
        }
        Update: {
          request_fingerprint?: string | null
          close_note?: string | null
          closed_at?: string | null
          created_at?: string
          created_by?: string | null
          expected_date?: string | null
          id?: string
          note?: string | null
          order_date?: string
          po_number?: string
          request_id?: string
          status?: string
          supplier_id?: string
          total_cents?: number
        }
        Relationships: [
          {
            foreignKeyName: "purchase_orders_created_by_fkey"
            columns: ["created_by"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "purchase_orders_supplier_id_fkey"
            columns: ["supplier_id"]
            isOneToOne: false
            referencedRelation: "suppliers"
            referencedColumns: ["id"]
          },
        ]
      }
      store_settings: {
        Row: {
          address: string | null
          contact_phone: string | null
          created_at: string
          currency: string
          description: string | null
          email: string | null
          id: boolean
          is_open: boolean
          maintenance_mode: boolean
          opening_hours: string | null
          retail_enabled: boolean
          show_banners: boolean
          show_featured_products: boolean
          show_new_arrivals: boolean
          show_stock_status: boolean
          store_name: string
          updated_at: string
          updated_by: string | null
          whatsapp_number: string | null
          wholesale_enabled: boolean
        }
        Insert: {
          address?: string | null
          contact_phone?: string | null
          created_at?: string
          currency?: string
          description?: string | null
          email?: string | null
          id?: boolean
          is_open?: boolean
          maintenance_mode?: boolean
          opening_hours?: string | null
          retail_enabled?: boolean
          show_banners?: boolean
          show_featured_products?: boolean
          show_new_arrivals?: boolean
          show_stock_status?: boolean
          store_name?: string
          updated_at?: string
          updated_by?: string | null
          whatsapp_number?: string | null
          wholesale_enabled?: boolean
        }
        Update: {
          address?: string | null
          contact_phone?: string | null
          created_at?: string
          currency?: string
          description?: string | null
          email?: string | null
          id?: boolean
          is_open?: boolean
          maintenance_mode?: boolean
          opening_hours?: string | null
          retail_enabled?: boolean
          show_banners?: boolean
          show_featured_products?: boolean
          show_new_arrivals?: boolean
          show_stock_status?: boolean
          store_name?: string
          updated_at?: string
          updated_by?: string | null
          whatsapp_number?: string | null
          wholesale_enabled?: boolean
        }
        Relationships: [
          {
            foreignKeyName: "store_settings_updated_by_fkey"
            columns: ["updated_by"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
        ]
      }
      supplier_payments: {
        Row: {
          request_fingerprint: string | null
          amount_cents: number
          created_at: string
          created_by: string | null
          id: string
          method: string
          note: string | null
          paid_on: string
          payment_number: string
          reference: string | null
          request_id: string
          supplier_id: string
          void_note: string | null
          voided_at: string | null
          voided_by: string | null
        }
        Insert: {
          request_fingerprint?: string | null
          amount_cents: number
          created_at?: string
          created_by?: string | null
          id?: string
          method: string
          note?: string | null
          paid_on: string
          payment_number: string
          reference?: string | null
          request_id: string
          supplier_id: string
          void_note?: string | null
          voided_at?: string | null
          voided_by?: string | null
        }
        Update: {
          request_fingerprint?: string | null
          amount_cents?: number
          created_at?: string
          created_by?: string | null
          id?: string
          method?: string
          note?: string | null
          paid_on?: string
          payment_number?: string
          reference?: string | null
          request_id?: string
          supplier_id?: string
          void_note?: string | null
          voided_at?: string | null
          voided_by?: string | null
        }
        Relationships: [
          {
            foreignKeyName: "supplier_payments_created_by_fkey"
            columns: ["created_by"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "supplier_payments_supplier_id_fkey"
            columns: ["supplier_id"]
            isOneToOne: false
            referencedRelation: "suppliers"
            referencedColumns: ["id"]
          },
        ]
      }
      supplier_return_items: {
        Row: {
          quantity: number
          grn_line_id: string | null
          from_status: string | null
          reversed_at: string | null
          barcode_snapshot: string | null
          grn_id: string | null
          id: string
          product_id: string | null
          product_name_snapshot: string
          serial_snapshot: string | null
          supplier_return_id: string
          unit_cost_cents: number
          unit_id: string | null
          variant_id: string | null
          variant_label_snapshot: string | null
        }
        Insert: {
          quantity?: number
          grn_line_id?: string | null
          from_status?: string | null
          reversed_at?: string | null
          barcode_snapshot: string | null
          grn_id?: string | null
          id?: string
          product_id?: string | null
          product_name_snapshot: string
          serial_snapshot?: string | null
          supplier_return_id: string
          unit_cost_cents: number
          unit_id: string | null
          variant_id?: string | null
          variant_label_snapshot?: string | null
        }
        Update: {
          quantity?: number
          grn_line_id?: string | null
          from_status?: string | null
          reversed_at?: string | null
          barcode_snapshot?: string | null
          grn_id?: string | null
          id?: string
          product_id?: string | null
          product_name_snapshot?: string
          serial_snapshot?: string | null
          supplier_return_id?: string
          unit_cost_cents?: number
          unit_id?: string | null
          variant_id?: string | null
          variant_label_snapshot?: string | null
        }
        Relationships: [
          {
            foreignKeyName: "supplier_return_items_supplier_return_id_fkey"
            columns: ["supplier_return_id"]
            isOneToOne: false
            referencedRelation: "supplier_returns"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "supplier_return_items_unit_id_fkey"
            columns: ["unit_id"]
            isOneToOne: false
            referencedRelation: "inventory_units"
            referencedColumns: ["id"]
          },
        ]
      }
      supplier_returns: {
        Row: {
          request_fingerprint: string | null
          reversed_at: string | null
          reversed_by: string | null
          reversal_note: string | null
          created_at: string
          created_by: string | null
          id: string
          note: string | null
          request_id: string
          return_date: string
          return_number: string
          return_type: string
          supplier_id: string
          total_cents: number
          total_units: number
        }
        Insert: {
          request_fingerprint?: string | null
          reversed_at?: string | null
          reversed_by?: string | null
          reversal_note?: string | null
          created_at?: string
          created_by?: string | null
          id?: string
          note?: string | null
          request_id: string
          return_date: string
          return_number: string
          return_type: string
          supplier_id: string
          total_cents?: number
          total_units?: number
        }
        Update: {
          request_fingerprint?: string | null
          reversed_at?: string | null
          reversed_by?: string | null
          reversal_note?: string | null
          created_at?: string
          created_by?: string | null
          id?: string
          note?: string | null
          request_id?: string
          return_date?: string
          return_number?: string
          return_type?: string
          supplier_id?: string
          total_cents?: number
          total_units?: number
        }
        Relationships: [
          {
            foreignKeyName: "supplier_returns_created_by_fkey"
            columns: ["created_by"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "supplier_returns_supplier_id_fkey"
            columns: ["supplier_id"]
            isOneToOne: false
            referencedRelation: "suppliers"
            referencedColumns: ["id"]
          },
        ]
      }
      suppliers: {
        Row: {
          address: string | null
          contact_person: string | null
          created_at: string
          created_by: string | null
          email: string | null
          id: string
          is_active: boolean
          name: string
          note: string | null
          opening_balance_cents: number | null
          phone: string | null
          supplier_code: string
          updated_at: string
        }
        Insert: {
          address?: string | null
          contact_person?: string | null
          created_at?: string
          created_by?: string | null
          email?: string | null
          id?: string
          is_active?: boolean
          name: string
          note?: string | null
          opening_balance_cents?: number | null
          phone?: string | null
          supplier_code: string
          updated_at?: string
        }
        Update: {
          address?: string | null
          contact_person?: string | null
          created_at?: string
          created_by?: string | null
          email?: string | null
          id?: string
          is_active?: boolean
          name?: string
          note?: string | null
          opening_balance_cents?: number | null
          phone?: string | null
          supplier_code?: string
          updated_at?: string
        }
        Relationships: [
          {
            foreignKeyName: "suppliers_created_by_fkey"
            columns: ["created_by"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
        ]
      }
      customer_refunds: {
        Row: {
          id: string
          refund_number: string
          source_type: string
          pos_sale_id: string | null
          order_id: string | null
          customer_return_id: string | null
          amount_cents: number
          method: string
          reference: string | null
          note: string | null
          created_by: string | null
          request_id: string
          request_fingerprint: string
          created_at: string
        }
        Insert: {
          id?: string
          refund_number?: string
          source_type?: string
          pos_sale_id?: string | null
          order_id?: string | null
          customer_return_id?: string | null
          amount_cents?: number
          method?: string
          reference?: string | null
          note?: string | null
          created_by?: string | null
          request_id?: string
          request_fingerprint?: string
          created_at?: string
        }
        Update: {
          id?: string
          refund_number?: string
          source_type?: string
          pos_sale_id?: string | null
          order_id?: string | null
          customer_return_id?: string | null
          amount_cents?: number
          method?: string
          reference?: string | null
          note?: string | null
          created_by?: string | null
          request_id?: string
          request_fingerprint?: string
          created_at?: string
        }
        Relationships: []
      }
      customer_return_items: {
        Row: {
          id: string
          customer_return_id: string
          pos_sale_item_id: string | null
          order_item_id: string | null
          unit_id: string | null
          quarantine_lot_id: string | null
          product_id: string | null
          variant_id: string | null
          product_name_snapshot: string
          variant_label_snapshot: string | null
          quantity: number
          condition: string
        }
        Insert: {
          id?: string
          customer_return_id?: string
          pos_sale_item_id?: string | null
          order_item_id?: string | null
          unit_id?: string | null
          quarantine_lot_id?: string | null
          product_id?: string | null
          variant_id?: string | null
          product_name_snapshot?: string
          variant_label_snapshot?: string | null
          quantity?: number
          condition?: string
        }
        Update: {
          id?: string
          customer_return_id?: string
          pos_sale_item_id?: string | null
          order_item_id?: string | null
          unit_id?: string | null
          quarantine_lot_id?: string | null
          product_id?: string | null
          variant_id?: string | null
          product_name_snapshot?: string
          variant_label_snapshot?: string | null
          quantity?: number
          condition?: string
        }
        Relationships: []
      }
      customer_returns: {
        Row: {
          id: string
          return_number: string
          source_type: string
          pos_sale_id: string | null
          order_id: string | null
          note: string | null
          created_by: string | null
          request_id: string
          request_fingerprint: string
          created_at: string
        }
        Insert: {
          id?: string
          return_number?: string
          source_type?: string
          pos_sale_id?: string | null
          order_id?: string | null
          note?: string | null
          created_by?: string | null
          request_id?: string
          request_fingerprint?: string
          created_at?: string
        }
        Update: {
          id?: string
          return_number?: string
          source_type?: string
          pos_sale_id?: string | null
          order_id?: string | null
          note?: string | null
          created_by?: string | null
          request_id?: string
          request_fingerprint?: string
          created_at?: string
        }
        Relationships: []
      }
      grn_corrections: {
        Row: {
          id: string
          grn_id: string
          grn_line_id: string
          quantity: number
          value_cents: number
          note: string
          request_id: string
          request_fingerprint: string
          created_by: string | null
          created_at: string
        }
        Insert: {
          id?: string
          grn_id?: string
          grn_line_id?: string
          quantity?: number
          value_cents?: number
          note?: string
          request_id?: string
          request_fingerprint?: string
          created_by?: string | null
          created_at?: string
        }
        Update: {
          id?: string
          grn_id?: string
          grn_line_id?: string
          quantity?: number
          value_cents?: number
          note?: string
          request_id?: string
          request_fingerprint?: string
          created_by?: string | null
          created_at?: string
        }
        Relationships: []
      }
      inventory_audit_log: {
        Row: {
          id: string
          entity_type: string
          entity_id: string
          action: string
          actor_id: string | null
          before_data: Json | null
          after_data: Json | null
          note: string | null
          created_at: string
        }
        Insert: {
          id?: string
          entity_type?: string
          entity_id?: string
          action?: string
          actor_id?: string | null
          before_data?: Json | null
          after_data?: Json | null
          note?: string | null
          created_at?: string
        }
        Update: {
          id?: string
          entity_type?: string
          entity_id?: string
          action?: string
          actor_id?: string | null
          before_data?: Json | null
          after_data?: Json | null
          note?: string | null
          created_at?: string
        }
        Relationships: []
      }
      inventory_locations: {
        Row: {
          code: string
          name: string
          is_sellable: boolean
        }
        Insert: {
          code?: string
          name?: string
          is_sellable?: boolean
        }
        Update: {
          code?: string
          name?: string
          is_sellable?: boolean
        }
        Relationships: []
      }
      inventory_policy: {
        Row: {
          id: boolean
          max_reserved_units_per_customer: number | null
          max_active_orders_per_customer: number | null
          staff_max_discount_bps: number
          updated_by: string | null
          updated_at: string
        }
        Insert: {
          id?: boolean
          max_reserved_units_per_customer?: number | null
          max_active_orders_per_customer?: number | null
          staff_max_discount_bps?: number
          updated_by?: string | null
          updated_at?: string
        }
        Update: {
          id?: boolean
          max_reserved_units_per_customer?: number | null
          max_active_orders_per_customer?: number | null
          staff_max_discount_bps?: number
          updated_by?: string | null
          updated_at?: string
        }
        Relationships: []
      }
      pos_discount_approvals: {
        Row: {
          id: string
          sale_request_id: string
          items_fingerprint: string
          requested_by: string
          requested_cents: number
          subtotal_cents: number
          reason: string
          status: string
          decided_by: string | null
          decided_at: string | null
          decision_note: string | null
          used_sale_id: string | null
          expires_at: string
          created_at: string
        }
        Insert: {
          id?: string
          sale_request_id?: string
          items_fingerprint?: string
          requested_by?: string
          requested_cents?: number
          subtotal_cents?: number
          reason?: string
          status?: string
          decided_by?: string | null
          decided_at?: string | null
          decision_note?: string | null
          used_sale_id?: string | null
          expires_at?: string
          created_at?: string
        }
        Update: {
          id?: string
          sale_request_id?: string
          items_fingerprint?: string
          requested_by?: string
          requested_cents?: number
          subtotal_cents?: number
          reason?: string
          status?: string
          decided_by?: string | null
          decided_at?: string | null
          decision_note?: string | null
          used_sale_id?: string | null
          expires_at?: string
          created_at?: string
        }
        Relationships: []
      }
      quarantine_lots: {
        Row: {
          id: string
          product_id: string
          variant_id: string | null
          quantity: number
          open_quantity: number
          released_quantity: number
          written_off_quantity: number
          customer_return_id: string | null
          note: string | null
          created_at: string
        }
        Insert: {
          id?: string
          product_id?: string
          variant_id?: string | null
          quantity?: number
          open_quantity?: number
          released_quantity?: number
          written_off_quantity?: number
          customer_return_id?: string | null
          note?: string | null
          created_at?: string
        }
        Update: {
          id?: string
          product_id?: string
          variant_id?: string | null
          quantity?: number
          open_quantity?: number
          released_quantity?: number
          written_off_quantity?: number
          customer_return_id?: string | null
          note?: string | null
          created_at?: string
        }
        Relationships: []
      }
      stock_reconciliation_flags: {
        Row: {
          id: string
          order_id: string
          order_item_id: string
          product_id: string | null
          variant_id: string | null
          quantity: number
          reason: string
          resolved_at: string | null
          resolved_by: string | null
          resolution_note: string | null
          created_at: string
        }
        Insert: {
          id?: string
          order_id?: string
          order_item_id?: string
          product_id?: string | null
          variant_id?: string | null
          quantity?: number
          reason?: string
          resolved_at?: string | null
          resolved_by?: string | null
          resolution_note?: string | null
          created_at?: string
        }
        Update: {
          id?: string
          order_id?: string
          order_item_id?: string
          product_id?: string | null
          variant_id?: string | null
          quantity?: number
          reason?: string
          resolved_at?: string | null
          resolved_by?: string | null
          resolution_note?: string | null
          created_at?: string
        }
        Relationships: []
      }
      stock_reservations: {
        Row: {
          id: string
          order_id: string
          order_item_id: string
          product_id: string
          variant_id: string | null
          holder_variant_id: string | null
          quantity: number
          status: string
          expires_at: string | null
          created_at: string
          closed_at: string | null
        }
        Insert: {
          id?: string
          order_id?: string
          order_item_id?: string
          product_id?: string
          variant_id?: string | null
          holder_variant_id?: string | null
          quantity?: number
          status?: string
          expires_at?: string | null
          created_at?: string
          closed_at?: string | null
        }
        Update: {
          id?: string
          order_id?: string
          order_item_id?: string
          product_id?: string
          variant_id?: string | null
          holder_variant_id?: string | null
          quantity?: number
          status?: string
          expires_at?: string | null
          created_at?: string
          closed_at?: string | null
        }
        Relationships: []
      }
      supplier_payment_allocations: {
        Row: {
          id: string
          payment_id: string
          grn_id: string
          amount_cents: number
        }
        Insert: {
          id?: string
          payment_id?: string
          grn_id?: string
          amount_cents?: number
        }
        Update: {
          id?: string
          payment_id?: string
          grn_id?: string
          amount_cents?: number
        }
        Relationships: []
      }
      user_roles: {
        Row: {
          granted_at: string
          granted_by: string | null
          id: string
          profile_id: string
          role: string
        }
        Insert: {
          granted_at?: string
          granted_by?: string | null
          id?: string
          profile_id: string
          role: string
        }
        Update: {
          granted_at?: string
          granted_by?: string | null
          id?: string
          profile_id?: string
          role?: string
        }
        Relationships: [
          {
            foreignKeyName: "user_roles_granted_by_fkey"
            columns: ["granted_by"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "user_roles_profile_id_fkey"
            columns: ["profile_id"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
        ]
      }
      wholesale_access_request_notes: {
        Row: {
          admin_notes: string
          request_id: string
          updated_at: string
          updated_by: string | null
        }
        Insert: {
          admin_notes: string
          request_id: string
          updated_at?: string
          updated_by?: string | null
        }
        Update: {
          admin_notes?: string
          request_id?: string
          updated_at?: string
          updated_by?: string | null
        }
        Relationships: [
          {
            foreignKeyName: "wholesale_access_request_notes_request_id_fkey"
            columns: ["request_id"]
            isOneToOne: true
            referencedRelation: "wholesale_access_requests"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "wholesale_access_request_notes_updated_by_fkey"
            columns: ["updated_by"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
        ]
      }
      wholesale_access_requests: {
        Row: {
          admin_updated_at: string | null
          admin_updated_by: string | null
          assistance_requested_at: string | null
          business_name: string
          business_registration: string | null
          business_type: string | null
          contact_phone: string | null
          created_at: string
          customer_values: Json | null
          id: string
          message: string | null
          monthly_volume: string | null
          profile_id: string
          review_note: string | null
          reviewed_at: string | null
          reviewed_by: string | null
          status: string
          submitted_at: string | null
          updated_at: string
        }
        Insert: {
          admin_updated_at?: string | null
          admin_updated_by?: string | null
          assistance_requested_at?: string | null
          business_name?: string
          business_registration?: string | null
          business_type?: string | null
          contact_phone?: string | null
          created_at?: string
          customer_values?: Json | null
          id?: string
          message?: string | null
          monthly_volume?: string | null
          profile_id: string
          review_note?: string | null
          reviewed_at?: string | null
          reviewed_by?: string | null
          status?: string
          submitted_at?: string | null
          updated_at?: string
        }
        Update: {
          admin_updated_at?: string | null
          admin_updated_by?: string | null
          assistance_requested_at?: string | null
          business_name?: string
          business_registration?: string | null
          business_type?: string | null
          contact_phone?: string | null
          created_at?: string
          customer_values?: Json | null
          id?: string
          message?: string | null
          monthly_volume?: string | null
          profile_id?: string
          review_note?: string | null
          reviewed_at?: string | null
          reviewed_by?: string | null
          status?: string
          submitted_at?: string | null
          updated_at?: string
        }
        Relationships: [
          {
            foreignKeyName: "wholesale_access_requests_admin_updated_by_fkey"
            columns: ["admin_updated_by"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "wholesale_access_requests_profile_id_fkey"
            columns: ["profile_id"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "wholesale_access_requests_reviewed_by_fkey"
            columns: ["reviewed_by"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
        ]
      }
      wishlist_items: {
        Row: {
          created_at: string
          product_id: string
          profile_id: string
        }
        Insert: {
          created_at?: string
          product_id: string
          profile_id: string
        }
        Update: {
          created_at?: string
          product_id?: string
          profile_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "wishlist_items_product_id_fkey"
            columns: ["product_id"]
            isOneToOne: false
            referencedRelation: "products"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "wishlist_items_profile_id_fkey"
            columns: ["profile_id"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
        ]
      }
    }
    Views: {
      my_effective_prices: {
        Row: {
          min_qty: number | null
          price_cents: number | null
          product_id: string | null
          tier_code: string | null
          variant_id: string | null
        }
        Relationships: [
          {
            foreignKeyName: "product_prices_product_id_fkey"
            columns: ["product_id"]
            isOneToOne: false
            referencedRelation: "products"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "product_prices_tier_code_fkey"
            columns: ["tier_code"]
            isOneToOne: false
            referencedRelation: "price_tiers"
            referencedColumns: ["code"]
          },
          {
            foreignKeyName: "product_prices_variant_id_fkey"
            columns: ["variant_id"]
            isOneToOne: false
            referencedRelation: "product_variants"
            referencedColumns: ["id"]
          },
        ]
      }
      my_prices: {
        Row: {
          id: string | null
          min_qty: number | null
          price_cents: number | null
          product_id: string | null
          tier_code: string | null
          variant_id: string | null
        }
        Insert: {
          id?: string | null
          min_qty?: number | null
          price_cents?: number | null
          product_id?: string | null
          tier_code?: string | null
          variant_id?: string | null
        }
        Update: {
          id?: string | null
          min_qty?: number | null
          price_cents?: number | null
          product_id?: string | null
          tier_code?: string | null
          variant_id?: string | null
        }
        Relationships: [
          {
            foreignKeyName: "product_prices_product_id_fkey"
            columns: ["product_id"]
            isOneToOne: false
            referencedRelation: "products"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "product_prices_tier_code_fkey"
            columns: ["tier_code"]
            isOneToOne: false
            referencedRelation: "price_tiers"
            referencedColumns: ["code"]
          },
          {
            foreignKeyName: "product_prices_variant_id_fkey"
            columns: ["variant_id"]
            isOneToOne: false
            referencedRelation: "product_variants"
            referencedColumns: ["id"]
          },
        ]
      }
    }
    Functions: {
      admin_close_purchase_order: {
        Args: { p_note: string; p_purchase_order_id: string }
        Returns: Json
      }
      admin_create_purchase_order: {
        Args: {
          p_expected_date: string | null
          p_lines: Json
          p_note: string
          p_order_date: string
          p_request_id: string
          p_supplier_id: string
        }
        Returns: Json
      }
      admin_review_wholesale_request: {
        Args: { p_note?: string; p_request_id: string; p_status: string }
        Returns: {
          admin_updated_at: string | null
          admin_updated_by: string | null
          assistance_requested_at: string | null
          business_name: string
          business_registration: string | null
          business_type: string | null
          contact_phone: string | null
          created_at: string
          customer_values: Json | null
          id: string
          message: string | null
          monthly_volume: string | null
          profile_id: string
          review_note: string | null
          reviewed_at: string | null
          reviewed_by: string | null
          status: string
          submitted_at: string | null
          updated_at: string
        }
        SetofOptions: {
          from: "*"
          to: "wholesale_access_requests"
          isOneToOne: true
          isSetofReturn: false
        }
      }
      admin_set_customer_type: {
        Args: {
          p_customer_type: string
          p_expires_at?: string
          p_profile_id: string
        }
        Returns: {
          avatar_url: string | null
          created_at: string
          customer_type: string
          email: string | null
          full_name: string | null
          id: string
          phone: string | null
          updated_at: string
          vip_approved_at: string | null
          vip_approved_by: string | null
          vip_expires_at: string | null
        }
        SetofOptions: {
          from: "*"
          to: "profiles"
          isOneToOne: true
          isSetofReturn: false
        }
      }
      admin_set_price: {
        Args: {
          p_min_qty?: number
          p_price_cents?: number
          p_product_id: string
          p_starts_at?: string
          p_tier_code?: string
          p_variant_id?: string
        }
        Returns: {
          created_at: string
          created_by: string | null
          ends_at: string | null
          id: string
          min_qty: number
          price_cents: number
          product_id: string
          starts_at: string
          tier_code: string
          updated_at: string
          variant_id: string | null
        }
        SetofOptions: {
          from: "*"
          to: "product_prices"
          isOneToOne: true
          isSetofReturn: false
        }
      }
      admin_set_stock: {
        Args: {
          p_expected_quantity: number
          p_new_quantity: number
          p_note: string
          p_product_id: string
          p_reason: string
          p_request_id: string
          p_variant_id: string
        }
        Returns: Json
      }
      admin_update_wholesale_request: {
        Args: { p_admin_notes?: string; p_fields?: Json; p_request_id: string }
        Returns: {
          admin_updated_at: string | null
          admin_updated_by: string | null
          assistance_requested_at: string | null
          business_name: string
          business_registration: string | null
          business_type: string | null
          contact_phone: string | null
          created_at: string
          customer_values: Json | null
          id: string
          message: string | null
          monthly_volume: string | null
          profile_id: string
          review_note: string | null
          reviewed_at: string | null
          reviewed_by: string | null
          status: string
          submitted_at: string | null
          updated_at: string
        }
        SetofOptions: {
          from: "*"
          to: "wholesale_access_requests"
          isOneToOne: true
          isSetofReturn: false
        }
      }
      admin_void_supplier_payment: {
        Args: { p_note: string; p_payment_id: string }
        Returns: Json
      }
      admin_issue_product_barcode: { Args: { p_product_id: string; p_variant_id: string | null }; Returns: Json }
      admin_register_manufacturer_barcode: { Args: { p_product_id: string; p_value: string; p_variant_id: string | null }; Returns: Json }
      admin_retire_product_barcode: { Args: { p_barcode_id: string; p_note: string }; Returns: Json }
      admin_write_off_units: {
        Args: { p_note: string; p_reason: string; p_unit_ids: string[] }
        Returns: Json
      }
      customer_save_wholesale_application: {
        Args: { p_action: string; p_fields: Json }
        Returns: {
          admin_updated_at: string | null
          admin_updated_by: string | null
          assistance_requested_at: string | null
          business_name: string
          business_registration: string | null
          business_type: string | null
          contact_phone: string | null
          created_at: string
          customer_values: Json | null
          id: string
          message: string | null
          monthly_volume: string | null
          profile_id: string
          review_note: string | null
          reviewed_at: string | null
          reviewed_by: string | null
          status: string
          submitted_at: string | null
          updated_at: string
        }
        SetofOptions: {
          from: "*"
          to: "wholesale_access_requests"
          isOneToOne: true
          isSetofReturn: false
        }
      }
      place_order: { Args: { p_lines: Json; p_notes?: string }; Returns: Json }
      admin_correct_grn_line: {
        Args: { p_grn_line_id: string; p_note: string; p_quantity: number | null; p_request_id: string; p_unit_ids: string[] | null }
        Returns: Json
      }
      admin_create_supplier_return: {
        Args: { p_codes: string[]; p_note: string; p_quantity_lines: Json; p_request_id: string; p_return_date: string; p_return_type: string; p_supplier_id: string }
        Returns: Json
      }
      admin_decide_discount_approval: {
        Args: { p_approval_id: string; p_approve: boolean; p_note: string | null }
        Returns: Json
      }
      admin_inventory_dashboard: {
        Args: never
        Returns: {
          product_id: string
          variant_id: string | null
          product_name: string
          variant_name: string | null
          category_name: string | null
          is_active: boolean
          tracking_mode: string
          stock_scope: string
          on_hand: number
          reserved: number
          available: number
          sold: number
          quarantined: number
          returned_to_supplier: number
          written_off: number
          serialised_units: number
          oldest_received_on: string | null
          stock_status: string
        }[]
      }
      admin_purchase_costs: {
        Args: { p_ids: string[]; p_kind: string }
        Returns: { id: string; parent_id: string | null; cents: number | null; pending: boolean; extra: Json | null }[]
      }
      admin_quarantine_units: { Args: { p_note: string; p_unit_ids: string[] }; Returns: Json }
      admin_receive_goods: {
        Args: {
          p_confirm_duplicate_invoice: boolean
          p_duplicate_invoice_note: string | null
          p_lines: Json
          p_note: string
          p_purchase_order_id: string | null
          p_received_on: string
          p_request_id: string
          p_source_name: string | null
          p_source_type: string
          p_supplier_id: string | null
          p_supplier_invoice: string
        }
        Returns: Json
      }
      admin_record_customer_refund: {
        Args: { p_amount_cents: number; p_customer_return_id: string | null; p_method: string; p_note: string; p_reference: string; p_request_id: string; p_source_id: string; p_source_type: string }
        Returns: Json
      }
      admin_record_customer_return: {
        Args: { p_items: Json; p_note: string; p_request_id: string; p_source_id: string; p_source_type: string }
        Returns: Json
      }
      admin_record_supplier_payment: {
        Args: { p_allocations: Json; p_amount_cents: number; p_method: string; p_note: string; p_paid_on: string; p_reference: string; p_request_id: string; p_supplier_id: string }
        Returns: Json
      }
      admin_release_quarantine_units: { Args: { p_note: string; p_unit_ids: string[] }; Returns: Json }
      admin_resolve_quarantine_lot: {
        Args: { p_expected_open: number; p_lot_id: string; p_note: string; p_release: number; p_write_off: number }
        Returns: Json
      }
      admin_resolve_stock_flag: { Args: { p_flag_id: string; p_note: string }; Returns: Json }
      admin_reverse_supplier_return: { Args: { p_note: string; p_return_id: string }; Returns: Json }
      admin_save_inventory_policy: {
        Args: { p_max_active_orders_per_customer: number | null; p_max_reserved_units_per_customer: number | null; p_note: string; p_staff_max_discount_bps: number }
        Returns: Json
      }
      admin_save_supplier: {
        Args: {
          p_address: string
          p_contact_person: string
          p_email: string
          p_id: string | null
          p_is_active: boolean
          p_name: string
          p_note: string
          p_opening_balance_cents: number | null
          p_opening_balance_note: string | null
          p_phone: string
        }
        Returns: Json
      }
      admin_set_grn_line_cost: { Args: { p_grn_line_id: string; p_note: string; p_unit_cost_cents: number }; Returns: Json }
      admin_set_tracking_mode: {
        Args: { p_mode: string; p_note: string; p_product_id: string; p_variant_id: string | null }
        Returns: Json
      }
      admin_supplier_balances: {
        Args: never
        Returns: {
          supplier_id: string
          opening_cents: number | null
          purchases_cents: number
          credit_returns_cents: number
          cash_returns_cents: number
          payments_cents: number
          balance_cents: number
          pending_cost_lines: number
        }[]
      }
      admin_supplier_open_grns: {
        Args: { p_supplier_id: string }
        Returns: { grn_id: string; grn_number: string; received_on: string; supplier_invoice: string | null; amount_cents: number; allocated_cents: number; outstanding_cents: number }[]
      }
      admin_supplier_statement: {
        Args: { p_supplier_id: string }
        Returns: { occurred_on: string; recorded_at: string; kind: string; reference: string; description: string; debit_cents: number | null; credit_cents: number }[]
      }
      catalog_availability: {
        Args: never
        Returns: { product_id: string; variant_id: string | null; legacy_key: string | null; available: number }[]
      }
      expire_pending_orders: { Args: { p_limit?: number }; Returns: Json }
      place_order_v2: { Args: { p_lines: Json; p_notes: string | null; p_request_id: string }; Returns: Json }
      pos_create_sale: {
        Args: {
          p_customer_name: string
          p_customer_phone: string
          p_customer_profile_id: string | null
          p_discount_approval_id: string | null
          p_discount_cents: number
          p_items: Json
          p_note: string
          p_payment_method: string
          p_payment_reference: string
          p_request_id: string
        }
        Returns: Json
      }
      pos_find_customer: {
        Args: { p_phone: string }
        Returns: { profile_id: string; full_name: string | null; phone: string | null; tier_code: string }[]
      }
      pos_check_prices: { Args: { p_customer_profile_id: string | null; p_expected_prices: Json; p_items: Json }; Returns: Json }
      pos_checkout: {
        Args: {
          p_customer_name: string
          p_customer_phone: string
          p_customer_profile_id: string | null
          p_discount_approval_id: string | null
          p_discount_cents: number
          p_expected_prices: Json
          p_items: Json
          p_note: string
          p_payment_method: string
          p_payment_reference: string
          p_request_id: string
        }
        Returns: Json
      }
      pos_scan: { Args: { p_code: string; p_customer_profile_id: string | null }; Returns: Json }
      pos_lookup_unit: { Args: { p_code: string; p_customer_profile_id: string | null }; Returns: Json }
      pos_quote_product: { Args: { p_customer_profile_id: string | null; p_product_id: string; p_variant_id: string | null }; Returns: Json }
      pos_request_discount_approval: {
        Args: { p_customer_profile_id: string | null; p_discount_cents: number; p_items: Json; p_reason: string; p_sale_request_id: string }
        Returns: Json
      }
    }
    Enums: {
      [_ in never]: never
    }
    CompositeTypes: {
      [_ in never]: never
    }
  }
}

type DatabaseWithoutInternals = Omit<Database, "__InternalSupabase">

type DefaultSchema = DatabaseWithoutInternals[Extract<keyof Database, "public">]

export type Tables<
  DefaultSchemaTableNameOrOptions extends
    | keyof (DefaultSchema["Tables"] & DefaultSchema["Views"])
    | { schema: keyof DatabaseWithoutInternals },
  TableName extends (DefaultSchemaTableNameOrOptions extends {
    schema: keyof DatabaseWithoutInternals
  }
    ? keyof (DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Tables"] &
        DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Views"])
    : never) = never,
> = DefaultSchemaTableNameOrOptions extends {
  schema: keyof DatabaseWithoutInternals
}
  ? (DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Tables"] &
      DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Views"])[TableName] extends {
      Row: infer R
    }
    ? R
    : never
  : DefaultSchemaTableNameOrOptions extends keyof (DefaultSchema["Tables"] &
        DefaultSchema["Views"])
    ? (DefaultSchema["Tables"] &
        DefaultSchema["Views"])[DefaultSchemaTableNameOrOptions] extends {
        Row: infer R
      }
      ? R
      : never
    : never

export type TablesInsert<
  DefaultSchemaTableNameOrOptions extends
    | keyof DefaultSchema["Tables"]
    | { schema: keyof DatabaseWithoutInternals },
  TableName extends (DefaultSchemaTableNameOrOptions extends {
    schema: keyof DatabaseWithoutInternals
  }
    ? keyof DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Tables"]
    : never) = never,
> = DefaultSchemaTableNameOrOptions extends {
  schema: keyof DatabaseWithoutInternals
}
  ? DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Tables"][TableName] extends {
      Insert: infer I
    }
    ? I
    : never
  : DefaultSchemaTableNameOrOptions extends keyof DefaultSchema["Tables"]
    ? DefaultSchema["Tables"][DefaultSchemaTableNameOrOptions] extends {
        Insert: infer I
      }
      ? I
      : never
    : never

export type TablesUpdate<
  DefaultSchemaTableNameOrOptions extends
    | keyof DefaultSchema["Tables"]
    | { schema: keyof DatabaseWithoutInternals },
  TableName extends (DefaultSchemaTableNameOrOptions extends {
    schema: keyof DatabaseWithoutInternals
  }
    ? keyof DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Tables"]
    : never) = never,
> = DefaultSchemaTableNameOrOptions extends {
  schema: keyof DatabaseWithoutInternals
}
  ? DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Tables"][TableName] extends {
      Update: infer U
    }
    ? U
    : never
  : DefaultSchemaTableNameOrOptions extends keyof DefaultSchema["Tables"]
    ? DefaultSchema["Tables"][DefaultSchemaTableNameOrOptions] extends {
        Update: infer U
      }
      ? U
      : never
    : never

export type Enums<
  DefaultSchemaEnumNameOrOptions extends
    | keyof DefaultSchema["Enums"]
    | { schema: keyof DatabaseWithoutInternals },
  EnumName extends (DefaultSchemaEnumNameOrOptions extends {
    schema: keyof DatabaseWithoutInternals
  }
    ? keyof DatabaseWithoutInternals[DefaultSchemaEnumNameOrOptions["schema"]]["Enums"]
    : never) = never,
> = DefaultSchemaEnumNameOrOptions extends {
  schema: keyof DatabaseWithoutInternals
}
  ? DatabaseWithoutInternals[DefaultSchemaEnumNameOrOptions["schema"]]["Enums"][EnumName]
  : DefaultSchemaEnumNameOrOptions extends keyof DefaultSchema["Enums"]
    ? DefaultSchema["Enums"][DefaultSchemaEnumNameOrOptions]
    : never

export type CompositeTypes<
  PublicCompositeTypeNameOrOptions extends
    | keyof DefaultSchema["CompositeTypes"]
    | { schema: keyof DatabaseWithoutInternals },
  CompositeTypeName extends (PublicCompositeTypeNameOrOptions extends {
    schema: keyof DatabaseWithoutInternals
  }
    ? keyof DatabaseWithoutInternals[PublicCompositeTypeNameOrOptions["schema"]]["CompositeTypes"]
    : never) = never,
> = PublicCompositeTypeNameOrOptions extends {
  schema: keyof DatabaseWithoutInternals
}
  ? DatabaseWithoutInternals[PublicCompositeTypeNameOrOptions["schema"]]["CompositeTypes"][CompositeTypeName]
  : PublicCompositeTypeNameOrOptions extends keyof DefaultSchema["CompositeTypes"]
    ? DefaultSchema["CompositeTypes"][PublicCompositeTypeNameOrOptions]
    : never

export const Constants = {
  graphql_public: {
    Enums: {},
  },
  public: {
    Enums: {},
  },
} as const

