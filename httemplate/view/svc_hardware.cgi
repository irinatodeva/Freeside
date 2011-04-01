<% include('elements/svc_Common.html',
            'table'        => 'svc_hardware',
            'labels'       => \%labels,
            'fields'       => \@fields,
          )
%>
<%init>

my $fields = FS::svc_hardware->table_info->{'fields'};
my %labels = map { $_ =>  ( ref($fields->{$_})
                             ? $fields->{$_}{'label'}
                             : $fields->{$_}
                         );
                 } keys %$fields;
my $model = { field => 'typenum',
              type  => 'text',
              value => sub { $_[0]->hardware_type->model }
            };
my $status = { field => 'statusnum',
               type  => 'text',
               value => sub { $_[0]->status_label }
            };
my @fields = ($model, qw( serial hw_addr ip_addr ), $status, 'note' );
</%init>
