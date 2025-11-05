-- Função para atualizar o timestamp automaticamente
create or replace function atualizar_timestamp()
returns trigger as $$
begin
    new.updated_at = timezone('utc'::text, now());
    return new;
end;
$$ language plpgsql;

-- ==============================
-- Tabela: empresas
-- ==============================
create table empresas (
    cnpj varchar(14) primary key,
    password text not null,
    created_at timestamptz default timezone('utc'::text, now()) not null,
    updated_at timestamptz default timezone('utc'::text, now()) not null,
    name text not null,
    photo_url text,
    email text not null,
    cellphone varchar(11),
    locate text[],
    description text
);

create trigger trg_atualiza_empresas
before update on empresas
for each row
execute function atualizar_timestamp();

-- ==============================
-- Tabela: produtos
-- ==============================
create table produtos (
    lote text primary key,
    empresa varchar(14) not null,
    created_at timestamptz default timezone('utc'::text, now()) not null,
    updated_at timestamptz default timezone('utc'::text, now()) not null,
    name text not null,
    photo_url text,
    expiration_date date,
    description text not null,
    tags text[],
    original_value numeric(10,2) not null,
    value numeric(10,2) not null,
    quantity smallint,
    constraint fk_produtos_empresa
        foreign key (empresa) references empresas (cnpj) on delete cascade
);

create trigger trg_atualiza_produtos
before update on produtos
for each row
execute function atualizar_timestamp();
